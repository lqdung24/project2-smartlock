import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/join_request_model.dart';
import '../repositories/member_repository.dart';
import '../services/member_service.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(MemberService());
});

final membersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final repository = ref.watch(memberRepositoryProvider);
  return await repository.getAllMembers();
});

final joinRequestsProvider = FutureProvider.autoDispose<List<JoinRequestModel>>((ref) async {
  final repository = ref.watch(memberRepositoryProvider);
  return await repository.getJoinRequests();
});

class MemberNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> removeMember(int memberId) async {
    state = const AsyncLoading();
    final repository = ref.read(memberRepositoryProvider);
    final success = await repository.removeMember(memberId);
    if (success) {
      ref.invalidate(membersProvider);
      state = const AsyncData(null);
    } else {
      state = AsyncError('Failed to remove member', StackTrace.current);
    }
  }
}

final memberNotifierProvider = NotifierProvider.autoDispose<MemberNotifier, AsyncValue<void>>(
  MemberNotifier.new,
);

class JoinRequestNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> acceptRequest(int requesterId) async {
    state = const AsyncLoading();
    final repository = ref.read(memberRepositoryProvider);
    final success = await repository.acceptRequest(requesterId);
    if (success) {
      ref.invalidate(joinRequestsProvider);
      ref.invalidate(membersProvider);
      state = const AsyncData(null);
    } else {
      state = AsyncError('Failed to accept request', StackTrace.current);
    }
  }
}

final joinRequestNotifierProvider = NotifierProvider.autoDispose<JoinRequestNotifier, AsyncValue<void>>(
  JoinRequestNotifier.new,
);