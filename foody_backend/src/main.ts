import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

function parseCorsOrigen(valor?: string): boolean | string | string[] {
  if (!valor || valor.trim() === '*' || valor.trim() === '') return true;
  const lista = valor
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return lista.length === 1 ? lista[0]! : lista;
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );
  app.enableCors({
    origin: parseCorsOrigen(process.env.CORS_ORIGEN),
    credentials: true,
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
