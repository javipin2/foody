import { DatabaseService } from '../../core/database/database.service';
import { AlmacenamientoService } from '../almacenamiento/almacenamiento.service';
export declare class DomiciliariosDocumentosService {
    private readonly database;
    private readonly almacenamiento;
    constructor(database: DatabaseService, almacenamiento: AlmacenamientoService);
    listarTiposRequeridos(): readonly ["cedula_frente", "cedula_reverso", "foto_vehiculo"];
    listarPorDomiciliario(domiciliarioId: string): Promise<{
        url: string;
        id: string;
        tipo: string;
        estado: string;
        motivo_rechazo: string | null;
        created_at: Date | string;
        revisado_por: string | null;
    }[]>;
    resumenCarga(domiciliarioId: string): Promise<{
        documentos: {
            url: string;
            id: string;
            tipo: string;
            estado: string;
            motivo_rechazo: string | null;
            created_at: Date | string;
            revisado_por: string | null;
        }[];
        faltantes: ("cedula_frente" | "cedula_reverso" | "foto_vehiculo")[];
        completo: boolean;
        pendientes_revision: number;
    }>;
    subir(domiciliarioId: string, tipo: string, archivo: Buffer): Promise<{
        id: string;
        tipo: "cedula_frente" | "cedula_reverso" | "foto_vehiculo";
        url: string;
        estado: string;
    }>;
}
