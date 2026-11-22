import { JwtPayload } from '../../core/auth/jwt-payload';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlmacenamientoService } from './almacenamiento.service';
import { SubirImagenQueryDto, SubirVideoQueryDto } from './dto/subir-media-query.dto';
export declare class AlmacenamientoController {
    private readonly almacenamiento;
    private readonly sucursalScope;
    constructor(almacenamiento: AlmacenamientoService, sucursalScope: SucursalScopeService);
    subirImagen(archivo: Express.Multer.File | undefined, usuario: JwtPayload, query: SubirImagenQueryDto): Promise<{
        ruta: string;
        url: string;
    }>;
    subirVideo(archivo: Express.Multer.File | undefined, usuario: JwtPayload, query: SubirVideoQueryDto): Promise<{
        ruta: string;
        url: string;
    }>;
    subirImagenProducto(productoId: string, archivo: Express.Multer.File | undefined, usuario: JwtPayload, sucursalIdQuery?: string): Promise<Record<string, unknown>>;
    subirImagenPromocion(promocionId: string, archivo: Express.Multer.File | undefined, usuario: JwtPayload, sucursalIdQuery?: string): Promise<Record<string, unknown>>;
    subirImagenCombo(comboId: string, archivo: Express.Multer.File | undefined, usuario: JwtPayload, sucursalIdQuery?: string): Promise<Record<string, unknown>>;
    subirImagenCategoria(categoriaId: string, archivo: Express.Multer.File | undefined, usuario: JwtPayload, sucursalIdQuery?: string): Promise<Record<string, unknown>>;
    private subirEntidad;
}
