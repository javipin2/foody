import { BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WebSocketServer } from 'ws';
import { DatabaseService } from '../database/database.service';
import { ImpresionService } from './impresion.service';

describe('ImpresionService combos por estación', () => {
  const envAnterior = process.env.FOODY_QA_SIN_EFECTOS;

  afterEach(() => {
    if (envAnterior === undefined) delete process.env.FOODY_QA_SIN_EFECTOS;
    else process.env.FOODY_QA_SIN_EFECTOS = envAnterior;
  });

  function crearServicio() {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    const estaciones = [
      {
        cocina_id: '00000000-0000-4000-8000-000000000001',
        cocina_nombre: 'Asados',
      },
      {
        cocina_id: '00000000-0000-4000-8000-000000000002',
        cocina_nombre: 'Bebidas',
      },
    ];
    const tareas = [
      {
        cocina_id: estaciones[0].cocina_id,
        nombre_combo: 'Picada Foody',
        nombre_snapshot: 'Carne asada',
        cantidad: 2,
        cantidad_combo: 1,
        tipo_item: 'producto',
        producto_padre_nombre_snapshot: null,
        componente_indice: 0,
      },
      {
        cocina_id: estaciones[1].cocina_id,
        nombre_combo: 'Picada Foody',
        nombre_snapshot: 'Limonada',
        cantidad: 1,
        cantidad_combo: 1,
        tipo_item: 'producto',
        producto_padre_nombre_snapshot: null,
        componente_indice: 1,
      },
    ];
    const jobs: Array<{ cocinaId: string; payload: { ticket: string } }> = [];
    const database = {
      consultarUno: jest.fn(async (sql: string) => {
        if (sql.includes('SELECT id FROM pedidos')) return { id: 'pedido-1' };
        if (sql.includes('UPDATE pedidos')) return { comanda_copia: 4 };
        if (sql.includes('SELECT p.numero_pedido')) {
          return {
            numero_pedido: 42,
            tipo: 'mesa',
            mesa_nombre: 'Mesa 3',
            created_at: new Date('2026-01-01T10:00:00.000Z'),
          };
        }
        throw new Error(`Consulta única inesperada: ${sql}`);
      }),
      consultar: jest.fn(async (sql: string, params: unknown[] = []) => {
        if (sql.includes('SELECT DISTINCT origen.cocina_id')) {
          const filter = params[2] as string | null;
          return estaciones.filter(
            (e) => filter == null || e.cocina_id === filter,
          );
        }
        if (sql.includes('SELECT pr.nombre, pi.cantidad')) return [];
        if (sql.includes('SELECT pcs.nombre_combo, t.nombre_snapshot')) {
          return tareas.filter((t) => t.cocina_id === params[2]);
        }
        if (sql.includes('INSERT INTO impresion_cocina_jobs')) {
          jobs.push({
            cocinaId: String(params[1]),
            payload: JSON.parse(String(params[3])) as { ticket: string },
          });
          return [];
        }
        if (sql.includes('UPDATE impresion_cocina_jobs')) return [];
        throw new Error(`Consulta inesperada: ${sql}`);
      }),
    } as unknown as DatabaseService;
    const config = { get: jest.fn() } as unknown as ConfigService;
    return {
      service: new ImpresionService(database, config),
      database,
      jobs,
      estaciones,
    };
  }

  it('encola solo las tareas de cada estación y no imprime la línea cobrable duplicada', async () => {
    const { service, jobs, estaciones } = crearServicio();

    await service.reimprimirPedido('pedido-1', 'sucursal-1');

    expect(jobs).toHaveLength(2);
    const asados = jobs.find((job) => job.cocinaId === estaciones[0].cocina_id);
    const bebidas = jobs.find(
      (job) => job.cocinaId === estaciones[1].cocina_id,
    );
    expect(asados?.payload.ticket).toContain(
      '[PREPARACIÓN COMBO: Picada Foody] 2x Carne asada',
    );
    expect(asados?.payload.ticket).not.toContain('Limonada');
    expect(bebidas?.payload.ticket).toContain(
      '[PREPARACIÓN COMBO: Picada Foody] 1x Limonada',
    );
    expect(bebidas?.payload.ticket).not.toContain('Carne asada');
    expect(
      jobs.every((job) => !job.payload.ticket.includes('1x Picada Foody')),
    ).toBe(true);
  });

  it('reimprime únicamente la estación solicitada', async () => {
    const { service, jobs, estaciones } = crearServicio();

    await service.reimprimirPedido(
      'pedido-1',
      'sucursal-1',
      estaciones[1].cocina_id,
    );

    expect(jobs).toHaveLength(1);
    expect(jobs[0].cocinaId).toBe(estaciones[1].cocina_id);
    expect(jobs[0].payload.ticket).toContain('Limonada');
  });

  it('rechaza reimpresión si la estación no tiene tareas activas en el pedido', async () => {
    const { service, jobs, estaciones } = crearServicio();

    await expect(
      service.reimprimirPedido(
        'pedido-1',
        'sucursal-1',
        '00000000-0000-4000-8000-000000000003',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(jobs).toHaveLength(0);
    expect(estaciones).toHaveLength(2);
  });

  it('marca enviado solo después de que el agente acepta el ticket de esa cocina', async () => {
    const { service, database, estaciones } = crearServicio();
    const enviarTicket = jest
      .spyOn(service as never, 'enviarTicket' as never)
      .mockResolvedValue({ exito: true } as never);

    await (
      service as never as { procesarJob: (job: unknown) => Promise<void> }
    ).procesarJob({
      id: 'job-1',
      payload: { ticket: 'ticket estación bebidas' },
      cocina_id: estaciones[1].cocina_id,
      intentos: 0,
      impresora_nombre: null,
      impresora_ip: null,
      impresora_tipo: null,
    });

    expect(enviarTicket).toHaveBeenCalledWith('ticket estación bebidas', {
      cocina_id: estaciones[1].cocina_id,
      impresora: null,
    });
    expect(database.consultar).toHaveBeenCalledWith(
      expect.stringContaining("SET estado = 'enviado'"),
      ['job-1', false],
    );
  });

  it('mantiene pendiente el job y registra el siguiente intento si falla el agente', async () => {
    const { service, database } = crearServicio();
    jest.spyOn(service as never, 'enviarTicket' as never).mockResolvedValue({
      exito: false,
      error: 'Agente no disponible',
    } as never);

    await (
      service as never as { procesarJob: (job: unknown) => Promise<void> }
    ).procesarJob({
      id: 'job-reintento',
      payload: { ticket: 'ticket retry' },
      cocina_id: '00000000-0000-4000-8000-000000000001',
      intentos: 2,
      impresora_nombre: null,
      impresora_ip: null,
      impresora_tipo: null,
    });

    expect(database.consultar).toHaveBeenCalledWith(
      expect.stringContaining('SET intentos = $2'),
      ['job-reintento', 3, 'Agente no disponible', 'pendiente'],
    );
  });

  it('envía al agente el ticket y la estación asignada usando el protocolo WebSocket', async () => {
    process.env.FOODY_QA_SIN_EFECTOS = '1';
    const server = new WebSocketServer({ port: 0, host: '127.0.0.1' });
    await new Promise<void>((resolve) => server.once('listening', resolve));
    try {
      const address = server.address();
      if (!address || typeof address === 'string') {
        throw new Error(
          'El servidor falso de impresión no abrió un puerto TCP.',
        );
      }
      const recibido = new Promise<Record<string, unknown>>((resolve) => {
        server.once('connection', (socket) => {
          socket.once('message', (raw) => {
            resolve(JSON.parse(raw.toString()) as Record<string, unknown>);
            socket.send(JSON.stringify({ exito: true, mensaje: 'aceptado' }));
          });
        });
      });
      const config = {
        get: jest.fn().mockReturnValue(`ws://127.0.0.1:${address.port}`),
      } as unknown as ConfigService;
      const service = new ImpresionService({} as DatabaseService, config);

      const respuesta = await (
        service as never as {
          enviarTicket: (ticket: string, meta: unknown) => Promise<unknown>;
        }
      ).enviarTicket('=== Cocina bebidas ===\n1x Limonada', {
        cocina_id: '00000000-0000-4000-8000-000000000002',
        impresora: null,
      });
      const payload = await recibido;

      expect(payload).toMatchObject({
        ticket: '=== Cocina bebidas ===\n1x Limonada',
        cocina_id: '00000000-0000-4000-8000-000000000002',
        impresora: null,
      });
      expect(respuesta).toMatchObject({ exito: true, mensaje: 'aceptado' });
    } finally {
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
  });
});
