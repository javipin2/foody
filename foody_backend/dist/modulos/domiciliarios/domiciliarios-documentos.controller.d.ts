import { JwtPayload } from '../../core/auth/jwt-payload';
import { DomiciliariosDocumentosService } from './domiciliarios-documentos.service';
export declare class DomiciliariosDocumentosController {
    private readonly documentos;
    constructor(documentos: DomiciliariosDocumentosService);
    tipos(): {
        tipos: readonly ["cedula_frente", "cedula_reverso", "foto_vehiculo"];
    };
    misDocumentos(usuario: JwtPayload): Promise<{
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
    subir(tipo: string, archivo: Express.Multer.File | undefined, usuario: JwtPayload): Promise<{
        id: string;
        tipo: "cedula_frente" | "cedula_reverso" | "foto_vehiculo";
        url: string;
        estado: string;
    }>;
}
