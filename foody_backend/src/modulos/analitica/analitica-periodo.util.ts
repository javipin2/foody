import { BadRequestException } from '@nestjs/common';
import {
  fechaHoyNegocio,
  ZONA_HORARIA_NEGOCIO,
} from '../../compartido/fecha-negocio.util';
import { PresetAnalitica } from './dto/filtro-analitica.dto';

const TZ = ZONA_HORARIA_NEGOCIO;
const MAX_DIAS_RANGO = 366;

export type PeriodoResuelto = {
  preset: string;
  desde: string;
  hasta: string;
  label: string;
};

export type PeriodoConComparativa = {
  periodo: PeriodoResuelto;
  anterior?: { desde: string; hasta: string };
};

export function hoyBogota(): string {
  return fechaHoyNegocio();
}

function addDaysYmd(ymd: string, dias: number): string {
  const dt = new Date(`${ymd}T12:00:00`);
  dt.setDate(dt.getDate() + dias);
  return dt.toISOString().slice(0, 10);
}

export function diasEntre(desde: string, hasta: string): number {
  const a = new Date(`${desde}T12:00:00`).getTime();
  const b = new Date(`${hasta}T12:00:00`).getTime();
  return Math.round((b - a) / 86_400_000) + 1;
}

function lunesSemana(ymd: string): string {
  const dt = new Date(`${ymd}T12:00:00`);
  const dia = dt.getDay();
  const offset = dia === 0 ? 6 : dia - 1;
  return addDaysYmd(ymd, -offset);
}

function mesCalendarioAnterior(ref: string): { desde: string; hasta: string } {
  const [anio, mes] = ref.split('-').map(Number);
  const prevMes = mes === 1 ? 12 : mes - 1;
  const prevAnio = mes === 1 ? anio - 1 : anio;
  const desde = `${prevAnio}-${String(prevMes).padStart(2, '0')}-01`;
  const ultimo = new Date(prevAnio, prevMes, 0).getDate();
  const hasta = `${prevAnio}-${String(prevMes).padStart(2, '0')}-${String(ultimo).padStart(2, '0')}`;
  return { desde, hasta };
}

function etiquetaPeriodo(preset: string, desde: string, hasta: string): string {
  const meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  switch (preset) {
    case 'hoy':
      return 'Hoy';
    case 'ayer':
      return 'Ayer';
    case 'semana':
      return 'Semana actual';
    case '7d':
      return 'Últimos 7 días';
    case '30d':
      return 'Últimos 30 días';
    case 'anio':
      return `Año ${desde.slice(0, 4)}`;
    case 'mes': {
      const m = Number(desde.slice(5, 7)) - 1;
      return `${meses[m]} ${desde.slice(0, 4)}`;
    }
    case 'mes_anterior': {
      const m = Number(desde.slice(5, 7)) - 1;
      return `${meses[m]} ${desde.slice(0, 4)}`;
    }
    default:
      return desde === hasta ? desde : `${desde} — ${hasta}`;
  }
}

function periodoAnteriorEquivalente(
  preset: PresetAnalitica,
  periodo: PeriodoResuelto,
): { desde: string; hasta: string } {
  if (preset === 'mes') {
    return mesCalendarioAnterior(periodo.desde);
  }
  if (preset === 'anio') {
    const anio = Number(periodo.desde.slice(0, 4)) - 1;
    return {
      desde: `${anio}-01-01`,
      hasta: `${anio}-12-31`,
    };
  }
  if (preset === 'mes_anterior') {
    return mesCalendarioAnterior(
      mesCalendarioAnterior(periodo.hasta).desde,
    );
  }
  const n = diasEntre(periodo.desde, periodo.hasta);
  const hastaAnterior = addDaysYmd(periodo.desde, -1);
  const desdeAnterior = addDaysYmd(hastaAnterior, -(n - 1));
  return { desde: desdeAnterior, hasta: hastaAnterior };
}

export function resolverPeriodoAnalitica(
  preset?: PresetAnalitica,
  desde?: string,
  hasta?: string,
  comparar?: string,
  compararDesde?: string,
  compararHasta?: string,
): PeriodoConComparativa {
  const hoy = hoyBogota();
  const elegido: PresetAnalitica = preset ?? (desde || hasta ? 'rango' : 'mes');

  let desdeRes: string;
  let hastaRes: string;

  switch (elegido) {
    case 'hoy':
      desdeRes = hoy;
      hastaRes = hoy;
      break;
    case 'ayer':
      desdeRes = addDaysYmd(hoy, -1);
      hastaRes = desdeRes;
      break;
    case 'semana':
      desdeRes = lunesSemana(hoy);
      hastaRes = hoy;
      break;
    case 'mes':
      desdeRes = `${hoy.slice(0, 7)}-01`;
      hastaRes = hoy;
      break;
    case 'mes_anterior': {
      const r = mesCalendarioAnterior(hoy);
      desdeRes = r.desde;
      hastaRes = r.hasta;
      break;
    }
    case '7d':
      hastaRes = hoy;
      desdeRes = addDaysYmd(hoy, -6);
      break;
    case '30d':
      hastaRes = hoy;
      desdeRes = addDaysYmd(hoy, -29);
      break;
    case 'anio':
      desdeRes = `${hoy.slice(0, 4)}-01-01`;
      hastaRes = hoy;
      break;
    case 'rango':
      if (!desde || !hasta) {
        throw new BadRequestException(
          'Indica desde y hasta cuando preset=rango',
        );
      }
      if (desde > hasta) {
        throw new BadRequestException('desde no puede ser posterior a hasta');
      }
      if (diasEntre(desde, hasta) > MAX_DIAS_RANGO) {
        throw new BadRequestException(
          `El rango no puede superar ${MAX_DIAS_RANGO} días`,
        );
      }
      desdeRes = desde;
      hastaRes = hasta;
      break;
    default:
      desdeRes = `${hoy.slice(0, 7)}-01`;
      hastaRes = hoy;
  }

  const periodo: PeriodoResuelto = {
    preset: elegido,
    desde: desdeRes,
    hasta: hastaRes,
    label: etiquetaPeriodo(elegido, desdeRes, hastaRes),
  };

  const quiereComparar = comparar === 'true' || comparar === '1';
  if (!quiereComparar) {
    return { periodo };
  }

  if (compararDesde && compararHasta) {
    if (compararDesde > compararHasta) {
      throw new BadRequestException(
        'comparar_desde no puede ser posterior a comparar_hasta',
      );
    }
    return {
      periodo,
      anterior: { desde: compararDesde, hasta: compararHasta },
    };
  }

  return {
    periodo,
    anterior: periodoAnteriorEquivalente(elegido, periodo),
  };
}
