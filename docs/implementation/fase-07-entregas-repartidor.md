# Fase 07 · Entregas del repartidor

**Rama:** `feat/fase-07-entregas-repartidor`
**Objetivo:** la experiencia del repartidor en modo demo, sin ubicación todavía: lista de pedidos asignados (en curso
arriba), detalle con mapa y **botón principal contextual** (*Picked up* → *Start delivery* → *Mark as delivered*),
confirmación al entregar, errores tipados en SnackBar y bloqueo por `CourierBusy`.
**Referencias:** definición §3.1 F6, F7, F5 · §5.1 flujo B (pasos 1–2, 4–6 sin ubicación) · §6.2, §6.3 · §8.4
(acciones con `AsyncNotifier` + `AsyncValue.guard`) · §12.1 (lista y detalle del repartidor).
**Requisitos previos:** fase 06 terminada (reutiliza tarjetas, línea de tiempo, mapa y panel).

> Al terminar, en demo como repartidor: RT-1043 se puede llevar de `assigned` a `delivered` con tres botones; el
> cliente (si abriera la app) vería los cambios; los errores se muestran legibles y el botón vuelve a habilitarse.
> Compartir ubicación, permisos y wakelock son de la fase 08.

---

## Paso 0 · Inicio de fase

`00-guia-general.md` §3.1.

## Paso 1 · Lista del repartidor (`courier_orders_screen.dart`)

Igual estructura que la del cliente (fase 06, paso 3), con estas diferencias:

- Título `deliveriesTitle` "My deliveries"; acción de ajustes `settings-open`.
- Secciones: `inProgressSection` "In progress" (`isInProgress`), `assignedSection` "Assigned" (`assigned`),
  `completedSection` "Completed" (terminados). Omite las vacías.
- `OrderCard(showCustomer: true)`: el repartidor ve el nombre del cliente.
- Vacío: `EmptyState(icon: Icons.delivery_dining_outlined, title: l10n.noDeliveriesTitle "No deliveries assigned", message: l10n.noDeliveriesHint "New orders assigned to you will show up here automatically.")`.
- Un pedido nuevo asignado aparece sin refrescar (llega por el stream; en demo no ocurre salvo en tests).
- Toca una tarjeta → `context.push(Routes.courierOrder(order.id))`.

## Paso 2 · Controlador de acciones (`lib/features/orders/presentation/order_action_controller.dart`)

```dart
@riverpod
class OrderActionController extends _$OrderActionController {
  @override
  FutureOr<void> build(String orderId) {}

  /// Moves the order to [action.target]. Errors stay in the state (AsyncError) for the UI to show.
  Future<void> run(OrderAction action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(ordersRepositoryProvider).advanceStatus(orderId, action.target),
    );
  }
}
```

- **No** llames al método `update` (choca con `AsyncNotifier.update`).
- El pedido en pantalla se actualiza solo por el stream (`orderProvider`), no con el valor devuelto.

## Paso 3 · Acción principal en el detalle (variante `courier`)

En `TrackingPanel`, si `role == courier`, debajo de la cabecera de estado va `CourierActionButton(order)`:

1. Calcula la acción:
   ```dart
   final orders = ref.watch(myOrdersProvider).value ?? const <Order>[];
   final state = ref.watch(availableOrderActionsProvider)(
     role: UserRole.courier,
     status: order.status,
     hasOtherOrderInProgress: hasOtherOrderInProgress(orders, order.id),
   );
   ```
   `null` → no se muestra botón (p. ej. `delivered`: en su lugar la cabecera "Delivered").
2. `FilledButton` a ancho completo (key e identifier `order-action-primary`) con el texto de la acción:
   `actionPickUp` "Picked up", `actionStartDelivery` "Start delivery", `actionMarkDelivered` "Mark as delivered".
3. Mientras `orderActionControllerProvider(order.id)` está `isLoading`: el botón muestra un `CircularProgressIndicator`
   pequeño y está deshabilitado (no se puede pulsar dos veces).
4. Si `state.enabled == false` (`courierBusy`): botón deshabilitado + texto de ayuda debajo `errorCourierBusy`
   ("Finish your current delivery before starting another one.").
5. `markDelivered` pide confirmación antes (`showDialog` con `AlertDialog`):
   título `confirmDeliveredTitle` "Mark as delivered?", cuerpo `confirmDeliveredBody` "Confirm that you handed order
   {code} to the customer.", botones *Cancel* y *Confirm* (key e identifier `confirm-delivered`). Solo si confirma se
   llama `run`.
6. Errores: en la pantalla,
   ```dart
   ref.listen(orderActionControllerProvider(orderId), (previous, next) {
     if (next case AsyncError(:final error)) showErrorSnackBar(error, context.l10n);
   });
   ```
   El estado del pedido **no** cambia (la BD/mock lo rechazó); el botón vuelve a habilitarse.
7. Tras `delivered`: el botón desaparece, la cabecera dice "Delivered" y la línea de tiempo lo añade.

## Paso 4 · Resto del panel del repartidor

Reutiliza las secciones de la fase 06 con estos cambios para `role == courier`:

- Contexto bajo la cabecera: `assigned` → `courierNextPickup` "Head to {pickupName} to pick up the order";
  `pickedUp` → `courierNextStart` "Start the delivery when you leave the store"; `inTransit` → ETA y distancia (en la
  fase 08, con su posición); `delivered` → "Delivered at {time}".
- En lugar de "Your courier", muestra `customerLabel` "Customer" + `customerName`.
- Mapa: en esta fase sin marcador de repartidor (la posición propia llega en la fase 08). Origen, destino y ruta sí.
- Sin sección "Last updated" (es del cliente).

## Paso 5 · Tests

| Archivo | Qué comprueba |
|---|---|
| `test/features/orders/presentation/courier_orders_screen_test.dart` | carga/vacío ("No deliveries assigned")/error con *Retry*; secciones Assigned (RT-1043) y Completed (RT-1035, RT-1029) con nombre del cliente; un pedido asignado nuevo (insertado en el store de test) aparece sin refrescar. |
| `test/features/orders/presentation/order_action_controller_test.dart` | `run(pickUp)` llama a `advanceStatus(id, pickedUp)` (mocktail) y termina en `AsyncData`; un `CourierBusyError` queda en `AsyncError` con ese error. |
| `test/features/orders/presentation/courier_detail_test.dart` | RT-1043: botón "Picked up" → tras pulsar pasa a "Start delivery" → "Mark as delivered" → diálogo → *Cancel* no cambia nada → *Confirm* → "Delivered", sin botón, `timeline-delivered` hecho; mientras carga el botón está deshabilitado; con un repositorio que lanza `InvalidTransitionError` aparece el SnackBar "This order can't move to that status." y el botón sigue disponible; con otro pedido en curso el botón "Picked up" está deshabilitado con el texto de `CourierBusy`; el cliente (rol customer) nunca ve `order-action-primary`. |

## Paso 6 · Verificación manual

Demo como repartidor en el emulador: lista (Assigned + Completed) → RT-1043 → *Picked up* → *Start delivery* →
*Mark as delivered* → confirmar → *Delivered*; volver: RT-1043 en Completed. Repite en modo oscuro.
Nota: en el demo, al tocar *Start delivery* ya se mueve la posición simulada en el `DemoStore`, pero el marcador del
repartidor no se ve hasta la fase 08 (es lo esperado).

## Paso 7 · Cierre

`00-guia-general.md` §3.3.

---

## Criterios de terminado

- [ ] Lista del repartidor con In progress / Assigned / Completed, nombre del cliente y estados de carga/vacío/error.
- [ ] Botón principal contextual con las 3 transiciones válidas; confirmación al entregar; spinner y sin doble pulsación.
- [ ] Errores tipados en SnackBar (`InvalidTransition`, `NotAssignedToYou`, `CourierBusy`, red) sin cambiar el estado.
- [ ] Bloqueo proactivo con `courierBusy` (`AvailableOrderActions`).
- [ ] Ids para Maestro: `order-action-primary`, `confirm-delivered`.
- [ ] `./tool/check.sh` en verde; CI en verde; PR mergeado; bitácora actualizada.
