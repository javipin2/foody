import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp, ServiceAccount } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { readFileSync } from 'fs';

@Injectable()
export class FcmService implements OnModuleInit {
  private readonly log = new Logger(FcmService.name);
  private listo = false;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    if (getApps().length > 0) {
      this.listo = true;
      return;
    }

    const ruta = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');
    const jsonRaw = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');

    try {
      if (ruta) {
        const cred = JSON.parse(readFileSync(ruta, 'utf8')) as ServiceAccount;
        initializeApp({ credential: cert(cred) });
        this.listo = true;
        this.log.log('Firebase Admin inicializado (archivo)');
        return;
      }
      if (jsonRaw) {
        const cred = JSON.parse(jsonRaw) as ServiceAccount;
        initializeApp({ credential: cert(cred) });
        this.listo = true;
        this.log.log('Firebase Admin inicializado (env JSON)');
        return;
      }
      this.log.warn(
        'FCM envío deshabilitado: define FIREBASE_SERVICE_ACCOUNT_PATH o FIREBASE_SERVICE_ACCOUNT_JSON',
      );
    } catch (e) {
      this.log.error(`No se pudo inicializar Firebase Admin: ${e}`);
    }
  }

  estaListo(): boolean {
    return this.listo;
  }

  async enviarMulticast(
    tokens: string[],
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ) {
    const unicos = [...new Set(tokens.filter((t) => t && t.length > 10))];
    if (!this.listo || unicos.length === 0) {
      return { enviados: 0, fallos: unicos.length, motivo: 'sin_fcm' as const };
    }

    const res = await getMessaging().sendEachForMulticast({
      tokens: unicos,
      notification,
      data,
    });

    return {
      enviados: res.successCount,
      fallos: res.failureCount,
      motivo: 'ok' as const,
    };
  }
}
