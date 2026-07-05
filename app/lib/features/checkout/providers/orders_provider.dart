import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';

part 'orders_provider.g.dart';

@riverpod
Future<OrdersResponse> orders(Ref ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    return const OrdersResponse(orders: [], count: 0);
  }
  return ref.watch(apiClientProvider).getOrders(uid);
}
