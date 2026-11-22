import { Global, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Module } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { DatabaseModule } from '../database/database.module';
import { UMBRALES_ALERTA } from '../../modulos/alertas/alertas-riesgo.service';

/**
 * Lee `configuracion_global_foody` y aplica a runtime (CFG-GLOBAL-DEAD).
 * Cache en memoria; invalidar tras PATCH super.
 */
@Injectable()
export class ConfiguracionGlobalService implements OnModuleInit {
  private readonly log = new Logger(ConfiguracionGlobalService.name);
  private cache = new Map<string, string>();

  constructor(private readonly database: DatabaseService) {}

  async onModuleInit() {
    await this.recargar();
  }

  async recargar(): Promise<void> {
    const filas = await this.database.consultar<{ clave: string; valor: string }>(
      `SELECT clave, valor FROM configuracion_global_foody`,
    );
    this.cache = new Map(filas.map((f) => [f.clave, f.valor]));
    this.aplicarUmbralesAlerta();
    this.log.log(`Config global cargada (${this.cache.size} claves)`);
  }

  valor(clave: string, defecto: string): string {
    const v = this.cache.get(clave);
    return v != null && v.trim() !== '' ? v.trim() : defecto;
  }

  numero(clave: string, defecto: number): number {
    const n = Number(this.valor(clave, String(defecto)));
    return Number.isFinite(n) ? n : defecto;
  }

  /** Segundos expiración oferta domicilio. */
  ofertaExpiraSeg(): number {
    return Math.max(10, this.numero('tiempo_expiracion_oferta_seg', 60));
  }

  /** Comisión Foody sobre costo domicilio (0–1). */
  comisionFoodyPct(): number {
    const pct = this.numero('comision_domiciliario_porcentaje', 15);
    return Math.min(1, Math.max(0, pct / 100));
  }

  radioInicialKm(): number {
    return Math.max(0.5, this.numero('radio_inicial_busqueda_km', 3));
  }

  ampliacionRadioKm(): number {
    return Math.max(0.5, this.numero('ampliacion_radio_km', 2));
  }

  intentosMaxBusqueda(): number {
    return Math.max(1, Math.floor(this.numero('intentos_max_busqueda', 3)));
  }

  private aplicarUmbralesAlerta(): void {
    UMBRALES_ALERTA.descuentoPorcentajeAlto = this.numero(
      'umbral_alerta_descuento_pct',
      30,
    );
    UMBRALES_ALERTA.cuadreCajaCOP = this.numero('umbral_alerta_cuadre_caja', 5000);
    UMBRALES_ALERTA.subidaCostoIngredientePct = this.numero(
      'umbral_alerta_costo_sube_pct',
      15,
    );
    UMBRALES_ALERTA.margenBajoPct = this.numero(
      'umbral_alerta_margen_bajo_pct',
      20,
    );
    UMBRALES_ALERTA.qrRecordatorioAprobacionMinutos = this.numero(
      'tiempo_aprobacion_mesera_min',
      3,
    );
    UMBRALES_ALERTA.intentosDomiciliario = this.intentosMaxBusqueda();
  }
}

@Global()
@Module({
  imports: [DatabaseModule],
  providers: [ConfiguracionGlobalService],
  exports: [ConfiguracionGlobalService],
})
export class ConfiguracionGlobalModule {}
