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
var ConfiguracionGlobalService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.ConfiguracionGlobalModule = exports.ConfiguracionGlobalService = void 0;
const common_1 = require("@nestjs/common");
const common_2 = require("@nestjs/common");
const database_service_1 = require("../database/database.service");
const database_module_1 = require("../database/database.module");
const alertas_riesgo_service_1 = require("../../modulos/alertas/alertas-riesgo.service");
let ConfiguracionGlobalService = ConfiguracionGlobalService_1 = class ConfiguracionGlobalService {
    database;
    log = new common_1.Logger(ConfiguracionGlobalService_1.name);
    cache = new Map();
    constructor(database) {
        this.database = database;
    }
    async onModuleInit() {
        await this.recargar();
    }
    async recargar() {
        const filas = await this.database.consultar(`SELECT clave, valor FROM configuracion_global_foody`);
        this.cache = new Map(filas.map((f) => [f.clave, f.valor]));
        this.aplicarUmbralesAlerta();
        this.log.log(`Config global cargada (${this.cache.size} claves)`);
    }
    valor(clave, defecto) {
        const v = this.cache.get(clave);
        return v != null && v.trim() !== '' ? v.trim() : defecto;
    }
    numero(clave, defecto) {
        const n = Number(this.valor(clave, String(defecto)));
        return Number.isFinite(n) ? n : defecto;
    }
    ofertaExpiraSeg() {
        return Math.max(10, this.numero('tiempo_expiracion_oferta_seg', 60));
    }
    comisionFoodyPct() {
        const pct = this.numero('comision_domiciliario_porcentaje', 15);
        return Math.min(1, Math.max(0, pct / 100));
    }
    radioInicialKm() {
        return Math.max(0.5, this.numero('radio_inicial_busqueda_km', 3));
    }
    ampliacionRadioKm() {
        return Math.max(0.5, this.numero('ampliacion_radio_km', 2));
    }
    intentosMaxBusqueda() {
        return Math.max(1, Math.floor(this.numero('intentos_max_busqueda', 3)));
    }
    aplicarUmbralesAlerta() {
        alertas_riesgo_service_1.UMBRALES_ALERTA.descuentoPorcentajeAlto = this.numero('umbral_alerta_descuento_pct', 30);
        alertas_riesgo_service_1.UMBRALES_ALERTA.cuadreCajaCOP = this.numero('umbral_alerta_cuadre_caja', 5000);
        alertas_riesgo_service_1.UMBRALES_ALERTA.subidaCostoIngredientePct = this.numero('umbral_alerta_costo_sube_pct', 15);
        alertas_riesgo_service_1.UMBRALES_ALERTA.margenBajoPct = this.numero('umbral_alerta_margen_bajo_pct', 20);
        alertas_riesgo_service_1.UMBRALES_ALERTA.qrRecordatorioAprobacionMinutos = this.numero('tiempo_aprobacion_mesera_min', 3);
        alertas_riesgo_service_1.UMBRALES_ALERTA.intentosDomiciliario = this.intentosMaxBusqueda();
    }
};
exports.ConfiguracionGlobalService = ConfiguracionGlobalService;
exports.ConfiguracionGlobalService = ConfiguracionGlobalService = ConfiguracionGlobalService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [database_service_1.DatabaseService])
], ConfiguracionGlobalService);
let ConfiguracionGlobalModule = class ConfiguracionGlobalModule {
};
exports.ConfiguracionGlobalModule = ConfiguracionGlobalModule;
exports.ConfiguracionGlobalModule = ConfiguracionGlobalModule = __decorate([
    (0, common_1.Global)(),
    (0, common_2.Module)({
        imports: [database_module_1.DatabaseModule],
        providers: [ConfiguracionGlobalService],
        exports: [ConfiguracionGlobalService],
    })
], ConfiguracionGlobalModule);
//# sourceMappingURL=configuracion-global.module.js.map