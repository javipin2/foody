import {
  BadRequestException,
  Controller,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { SuscripcionActivaGuard } from '../../core/auth/guards/suscripcion-activa.guard';
import { UsuarioActivoGuard } from '../../core/auth/guards/usuario-activo.guard';
import { SucursalScopeService } from '../../core/auth/sucursal-scope.service';
import { AlmacenamientoService } from './almacenamiento.service';
import {
  SubirImagenQueryDto,
  SubirVideoQueryDto,
} from './dto/subir-media-query.dto';

@Controller('almacenamiento')
@UseGuards(JwtAuthGuard, UsuarioActivoGuard, SuscripcionActivaGuard, RolGuard)
export class AlmacenamientoController {
  constructor(
    private readonly almacenamiento: AlmacenamientoService,
    private readonly sucursalScope: SucursalScopeService,
  ) {}

  @Post('imagen')
  @Permisos('editar_productos')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async subirImagen(
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: SubirImagenQueryDto,
  ) {
    if (!archivo?.buffer?.length) {
      throw new BadRequestException('Falta el archivo «archivo» (multipart)');
    }
    if (!archivo.mimetype?.startsWith('image/')) {
      throw new BadRequestException('Solo se permiten imágenes');
    }
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      query.sucursal_id,
    );
    const tipo = this.almacenamiento.parseTipoImagen(query.tipo);
    return this.almacenamiento.subirImagenDesdeSucursal(archivo.buffer, {
      sucursalId,
      tipo,
      entidadId: query.entidad_id,
    });
  }

  /** Video para estados (máx 20 MB; duración ≤30 s en cliente). */
  @Post('video')
  @Permisos('editar_productos')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 20 * 1024 * 1024 },
    }),
  )
  async subirVideo(
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
    @Query() query: SubirVideoQueryDto,
  ) {
    if (!archivo?.buffer?.length) {
      throw new BadRequestException('Falta el archivo «archivo» (multipart)');
    }
    if (!archivo.mimetype?.startsWith('video/')) {
      throw new BadRequestException('Solo se permiten videos');
    }
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      query.sucursal_id,
    );
    return this.almacenamiento.subirVideoDesdeSucursal(archivo.buffer, {
      sucursalId,
      tipoQuery: query.tipo,
      contentType: archivo.mimetype,
      originalName: archivo.originalname,
    });
  }

  @Post('productos/:productoId/imagen')
  @Permisos('editar_productos')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async subirImagenProducto(
    @Param('productoId', ParseUUIDPipe) productoId: string,
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalIdQuery?: string,
  ) {
    return this.subirEntidad('producto', productoId, archivo, usuario, sucursalIdQuery);
  }

  @Post('promociones/:promocionId/imagen')
  @Permisos('editar_productos')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async subirImagenPromocion(
    @Param('promocionId', ParseUUIDPipe) promocionId: string,
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalIdQuery?: string,
  ) {
    return this.subirEntidad(
      'promocion',
      promocionId,
      archivo,
      usuario,
      sucursalIdQuery,
    );
  }

  @Post('combos/:comboId/imagen')
  @Permisos('editar_productos')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async subirImagenCombo(
    @Param('comboId', ParseUUIDPipe) comboId: string,
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalIdQuery?: string,
  ) {
    return this.subirEntidad('combo', comboId, archivo, usuario, sucursalIdQuery);
  }

  @Post('categorias/:categoriaId/imagen')
  @Permisos('editar_productos')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 5 * 1024 * 1024 },
    }),
  )
  async subirImagenCategoria(
    @Param('categoriaId', ParseUUIDPipe) categoriaId: string,
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
    @Query('sucursal_id') sucursalIdQuery?: string,
  ) {
    return this.subirEntidad(
      'categoria',
      categoriaId,
      archivo,
      usuario,
      sucursalIdQuery,
    );
  }

  private async subirEntidad(
    tipo: 'producto' | 'promocion' | 'combo' | 'categoria',
    entidadId: string,
    archivo: Express.Multer.File | undefined,
    usuario: JwtPayload,
    sucursalIdQuery?: string,
  ) {
    if (!archivo?.buffer?.length) {
      throw new BadRequestException('Falta el archivo «archivo»');
    }
    const sucursalId = await this.sucursalScope.resolverEscritura(
      usuario,
      sucursalIdQuery,
    );
    return this.almacenamiento.subirImagenEntidadCatalogo(archivo.buffer, {
      sucursalId,
      tipo,
      entidadId,
    });
  }
}
