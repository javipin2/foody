"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const app_module_1 = require("./app.module");
function parseCorsOrigen(valor) {
    if (!valor || valor.trim() === '*' || valor.trim() === '')
        return true;
    const lista = valor
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
    return lista.length === 1 ? lista[0] : lista;
}
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        transform: true,
    }));
    app.enableCors({
        origin: parseCorsOrigen(process.env.CORS_ORIGEN),
        credentials: true,
    });
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
//# sourceMappingURL=main.js.map