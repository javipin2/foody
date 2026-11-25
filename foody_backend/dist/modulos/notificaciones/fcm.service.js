"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var FcmService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.FcmService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const fs_1 = require("fs");
const qa_safety_1 = require("../../core/config/qa-safety");
let FcmService = FcmService_1 = class FcmService {
    config;
    log = new common_1.Logger(FcmService_1.name);
    listo = false;
    constructor(config) {
        this.config = config;
    }
    onModuleInit() {
        if ((0, qa_safety_1.esQaSinEfectosExternos)()) {
            this.log.warn('Firebase Admin desactivado por FOODY_QA_SIN_EFECTOS');
            return;
        }
        if ((0, app_1.getApps)().length > 0) {
            this.listo = true;
            return;
        }
        const ruta = this.config.get('FIREBASE_SERVICE_ACCOUNT_PATH');
        const jsonRaw = this.config.get('FIREBASE_SERVICE_ACCOUNT_JSON');
        try {
            if (ruta) {
                const cred = JSON.parse((0, fs_1.readFileSync)(ruta, 'utf8'));
                (0, app_1.initializeApp)({ credential: (0, app_1.cert)(cred) });
                this.listo = true;
                this.log.log('Firebase Admin inicializado (archivo)');
                return;
            }
            if (jsonRaw) {
                const cred = JSON.parse(jsonRaw);
                (0, app_1.initializeApp)({ credential: (0, app_1.cert)(cred) });
                this.listo = true;
                this.log.log('Firebase Admin inicializado (env JSON)');
                return;
            }
            this.log.warn('FCM envío deshabilitado: define FIREBASE_SERVICE_ACCOUNT_PATH o FIREBASE_SERVICE_ACCOUNT_JSON');
        }
        catch (e) {
            this.log.error(`No se pudo inicializar Firebase Admin: ${e}`);
        }
    }
    estaListo() {
        return this.listo;
    }
    async enviarMulticast(tokens, notification, data) {
        const unicos = [...new Set(tokens.filter((t) => t && t.length > 10))];
        if (!this.listo || unicos.length === 0) {
            return { enviados: 0, fallos: unicos.length, motivo: 'sin_fcm' };
        }
        const res = await (0, messaging_1.getMessaging)().sendEachForMulticast({
            tokens: unicos,
            notification,
            data,
        });
        return {
            enviados: res.successCount,
            fallos: res.failureCount,
            motivo: 'ok',
        };
    }
};
exports.FcmService = FcmService;
exports.FcmService = FcmService = FcmService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], FcmService);
//# sourceMappingURL=fcm.service.js.map