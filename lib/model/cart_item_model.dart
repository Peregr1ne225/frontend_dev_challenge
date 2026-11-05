import 'deal_model.dart';
import 'reservation_model.dart';

class CartItemModel {
  final DealModel deal;
  int quantity;

  /// Confirmed stock holds for this line. The reservation flow creates one
  /// quantity-one hold per bag unit so a single unit can be released or expire
  /// without affecting the rest of the line.
  final List<ReservationModel> reservations;

  /// Units shown optimistically while their reservation requests are pending.
  int pendingReservations;

  CartItemModel({
    required this.deal,
    this.quantity = 1,
    List<ReservationModel>? reservations,
    this.pendingReservations = 0,
  }) : reservations = reservations ?? <ReservationModel>[];

  int get confirmedQuantity => reservations.fold(
        0,
        (total, reservation) => total + reservation.quantity,
      );

  int get unreservedQuantity =>
      quantity - confirmedQuantity - pendingReservations;

  num get lineTotal => deal.price * quantity;
}
