import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/face_model.dart';
import '../repositories/face_repository.dart';
import '../services/face_service.dart';

final faceRepositoryProvider = Provider<FaceRepository>((ref) {
  return FaceRepository(FaceService());
});

final facesProvider = FutureProvider.autoDispose<List<FaceModel>>((ref) async {
  final repository = ref.watch(faceRepositoryProvider);
  return await repository.getAllFaces();
});

class FaceNotifier extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> registerFace(String imageUrl, String label) async {
    state = const AsyncLoading();
    final repository = ref.read(faceRepositoryProvider);
    try {
      await repository.registerFace(imageUrl, label);
      ref.invalidate(facesProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> deleteFace(int id, String hardwareId) async {
    state = const AsyncLoading();
    final repository = ref.read(faceRepositoryProvider);
    try {
      await repository.deleteFace(id, hardwareId);
      ref.invalidate(facesProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> updateFace(int id, String label) async {
    state = const AsyncLoading();
    final repository = ref.read(faceRepositoryProvider);
    try {
      await repository.updateFace(id, label);
      ref.invalidate(facesProvider);
      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}

final faceNotifierProvider = NotifierProvider.autoDispose<FaceNotifier, AsyncValue<void>>(
  FaceNotifier.new,
);