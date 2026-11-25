import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { validarConfigProduccion } from './core/config/validar-config-produccion';

const LOCALHOST_CORS =
  /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i;

function parseCorsOrigen(
  valor?: string,
): boolean | string | string[] | ((origin: string, callback: (err: Error | null, allow?: boolean) => void) => void) {
  const esDev = process.env.ENTORNO !== 'produccion';
  const lista = (valor ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);

  if (esDev) {
    return (origin, callback) => {
      if (!origin || LOCALHOST_CORS.test(origin) || lista.includes(origin)) {
        callback(null, true);
        return;
      }
      callback(null, false);
    };
  }

  if (!valor || valor.trim() === '*' || valor.trim() === '') return true;
  return lista.length === 1 ? lista[0]! : lista;
}

async function bootstrap() {
  validarConfigProduccion();
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      // BN-PIPE-04: no enableImplicitConversion global (rompe IsBoolean query
      // "false"→true en algunos casos). Query nums/bools: @Type() en DTOs.
    }),
  );
  app.enableCors({
    origin: parseCorsOrigen(process.env.CORS_ORIGEN),
    credentials: true,
    // Evita repetir OPTIONS en cada lectura desde el panel web. La API sigue
    // validando CORS en cada respuesta; esto solo cachea el permiso previo.
    maxAge: 300,
  });

  // Chrome (Flutter web en localhost) exige este header para llamar a IP LAN / WSL.
  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Private-Network', 'true');
    next();
  });

  const puerto = Number(process.env.PUERTO) || 3000;
  const host = process.env.HOST || '0.0.0.0';
  await app.listen(puerto, host);
  console.log(`Foody API en http://localhost:${puerto}/api/v1 (escucha en ${host})`);
}

bootstrap();
