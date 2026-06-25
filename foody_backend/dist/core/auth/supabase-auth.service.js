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
Object.defineProperty(exports, "__esModule", { value: true });
exports.SupabaseAuthService = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const supabase_js_1 = require("@supabase/supabase-js");
let SupabaseAuthService = class SupabaseAuthService {
    client;
    constructor(config) {
        const url = config.get('SUPABASE_URL');
        const key = config.get('SUPABASE_SERVICE_KEY');
        this.client = url && key ? (0, supabase_js_1.createClient)(url, key) : null;
    }
    estaConfigurado() {
        return this.client != null;
    }
    async usuarioDesdeAccessToken(accessToken) {
        if (!this.client) {
            throw new common_1.ServiceUnavailableException('Inicio con Google no disponible (falta configuración Supabase)');
        }
        const token = accessToken?.trim();
        if (!token) {
            throw new common_1.UnauthorizedException('Token de acceso inválido');
        }
        const { data, error } = await this.client.auth.getUser(token);
        if (error || !data.user) {
            throw new common_1.UnauthorizedException('Token de Google inválido o expirado');
        }
        if (!data.user.email) {
            throw new common_1.UnauthorizedException('La cuenta de Google no tiene correo asociado');
        }
        return data.user;
    }
};
exports.SupabaseAuthService = SupabaseAuthService;
exports.SupabaseAuthService = SupabaseAuthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [config_1.ConfigService])
], SupabaseAuthService);
//# sourceMappingURL=supabase-auth.service.js.map