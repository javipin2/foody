# Funciones de Firebase (Cloud Functions) – proyecto-20bae

Resumen de las funciones desplegadas, cuándo se ejecutan y cómo consumen recursos.

---

## Listado de funciones

| Función | Tipo | Cuándo se ejecuta | Uso en la app |
|--------|------|-------------------|----------------|
| **registerFcmToken** | Callable (HTTPS) | Cuando la app lo llama | Al elegir/cambiar ciudad: registra el token para notificaciones de **promociones** por ciudad. |
| **registerFcmTokenAudit** | Callable (HTTPS) | Cuando la app lo llama | Al entrar el **superadmin** al dashboard (o a Auditoría): registra el token para notificaciones de **auditoría** de su lugar. |
| **updateUserAuth** | Callable (HTTPS) | Cuando la app lo llama | Pantalla de programador: actualizar email/contraseña de usuarios (solo programador/superadmin). |
| **cleanupStaleFcmTokens** | Programada (Schedule) | **Cada día a las 3:00** | Elimina tokens FCM viejos: 90 días para promos, 180 días para auditoría. |
| **cleanupPendingReservations** | Programada (Schedule) | **Desactivada temporalmente** | Pasa reservas pendientes expiradas a `reservas_historial`; no se ejecuta hasta que se reactive en `functions/index.js`. |
| **cleanupOldPromociones** | Programada (Schedule) | **Cada domingo a las 4:00** | Elimina promociones con `fecha` anterior a hoy (máx 500 por ejecución). |
| **notifyPromocionCreated** | Trigger (Firestore) | Al **crear** un documento en `promociones/{promoId}` | Envía push a usuarios que eligieron esa ciudad (notificación de nueva promoción). |
| **notifyAuditoriaAltaRiesgo** | Trigger (Firestore) | Al **crear** un documento en `auditoria/{auditId}` con riesgo alto/crítico | Envía push al **superadmin** del lugar correspondiente. |

---

## ¿Hay conflictos con una configuración anterior?

**No.** Al hacer `firebase deploy --only functions`:

- Las funciones que **ya existían** (mismo nombre) se **actualizan**: se reemplaza solo el código. No se duplican.
- La única función **nueva** en este despliegue fue **cleanupOldPromociones** (apareció como "create"); el resto fueron "update".

Si antes tenías otras funciones con **otros nombres** en la consola de Firebase, esas siguen existiendo y no se tocan con este deploy. Solo las que están definidas en tu `functions/index.js` se actualizan o crean.

---

## ¿Consumen recursos solo por existir?

- **No consumen CPU/memoria** cuando están “idle”. Las Cloud Functions (2nd Gen) se ejecutan solo cuando:
  - Alguien llama a una **callable** (registerFcmToken, registerFcmTokenAudit, updateUserAuth).
  - Ocurre el **trigger** (nueva promoción o nueva auditoría).
  - Llega la **hora programada** (cleanupStaleFcmTokens, cleanupOldPromociones; cleanupPendingReservations está desactivada).

- **Sí consumen** en cada ejecución:
  - **Invocaciones**: cada ejecución cuenta como 1 invocación.
  - **Tiempo de CPU y memoria**: según cuánto dure la función y la memoria asignada (por defecto suele ser poco).

Las programadas son las que más invocaciones generan:
- **cleanupPendingReservations**: desactivada (antes 144 invocaciones/día).
- **cleanupStaleFcmTokens**: **1 invocación/día** (3:00).
- **cleanupOldPromociones**: **1 invocación/semana** (domingo 4:00).

El plan gratuito de Firebase suele incluir 2M invocaciones/mes; con este uso es difícil llegar al límite.

---

## Resumen rápido

- Todas las funciones del `index.js` actual están en uso y tienen un propósito claro; no hay duplicados por el deploy.
- Las **callables** y **triggers** solo consumen cuando la app o Firestore las disparan.
- Las **programadas** consumen según su cron (cada 10 min, diaria o semanal).
- Si en la consola ves funciones **antiguas con nombres distintos** a los de la tabla y ya no las usas, puedes eliminarlas desde Firebase Console → Functions para evitar invocaciones o confusión.

Si quieres, en el próximo paso podemos revisar juntos la lista exacta que te sale en la consola y marcar cuáles borrar.
