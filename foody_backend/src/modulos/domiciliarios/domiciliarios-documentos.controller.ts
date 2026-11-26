import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Permisos } from '../../compartido/decoradores/permisos.decorator';
import { UsuarioActual } from '../../compartido/decoradores/usuario-actual.decorator';
import { DomiciliarioCuentaGuard } from '../../core/auth/guards/domiciliario-cuenta.guard';
import { JwtAuthGuard } from '../../core/auth/guards/jwt-auth.guard';
import { RolGuard } from '../../core/auth/guards/rol.guard';
import { JwtPayload } from '../../core/auth/jwt-payload';
import { DomiciliariosDocumentosService } from './domiciliarios-documentos.service';

@Controller('domiciliarios')
@UseGuards(JwtAuthGuard, DomiciliarioCuentaGuard, RolGuard)
export class DomiciliariosDocumentosController {
  constructor(private readonly documentos: DomiciliariosDocumentosService) {}

  @Get('documentos/tipos')
  @Permisos('domiciliario_independiente')
  tipos() {
    return { tipos: this.documentos.listarTiposRequeridos() };
  }

  @Get('documentos')
  @Permisos('domiciliario_independiente')
  misDocumentos(@UsuarioActual() usuario: JwtPayload) {
    return this.documentos.resumenCarga(usuario.sub);
  }

  @Post('documentos/:tipo')
  @Permisos('domiciliario_independiente')
  @UseInterceptors(
    FileInterceptor('archivo', {
      limits: { fileSize: 5 * 1024 * 1024 },
      fileFilter: (_req, archivo, cb) => {
        if (
          !['image/jpeg', 'image/png', 'image/webp'].includes(archivo.mimetype)
        ) {
          // Multer errors thrown from fileFilter bypass Nest's HttpException
          // mapping in this setup and surface as 500. Reject the file normally;
          // the handler below returns the expected 400 for a missing upload.
          cb(null, false);
          return;
        }
        cb(null, true);
      },
    }),
  )
  subir(
    @Param('tipo') tipo: string,
    @UploadedFile() archivo: Express.Multer.File | undefined,
    @UsuarioActual() usuario: JwtPayload,
  ) {
    if (!archivo?.buffer?.length) {
      throw new BadRequestException('Debes adjuntar una imagen');
    }
    return this.documentos.subir(usuario.sub, tipo, archivo.buffer);
  }
}
