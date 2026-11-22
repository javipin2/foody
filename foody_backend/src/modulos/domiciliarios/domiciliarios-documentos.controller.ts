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
