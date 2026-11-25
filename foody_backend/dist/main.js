"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const app_module_1 = require("./app.module");
const validar_config_produccion_1 = require("./core/config/validar-config-produccion");
const LOCALHOST_CORS = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i;
function parseCorsOrigen(valor) {
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
    if (!valor || valor.trim() === '*' || valor.trim() === '')
        return true;
    return lista.length === 1 ? lista[0] : lista;
}
async function bootstrap() {
    (0, validar_config_produccion_1.validarConfigProduccion)();
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new common_1.ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
    }));
    app.enableCors({
        origin: parseCorsOrigen(process.env.CORS_ORIGEN),
        credentials: true,
        maxAge: 300,
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