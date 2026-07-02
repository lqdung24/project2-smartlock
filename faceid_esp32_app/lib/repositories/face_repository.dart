import '../models/face_model.dart';
import '../services/face_service.dart';

class FaceRepository {
  final FaceService _faceService;

  FaceRepository(this._faceService);

  Future<List<FaceModel>> getAllFaces() {
    return _faceService.getAllFaces();
  }

  Future<void> registerFace(String imageUrl, String label) {
    return _faceService.registerFace(imageUrl, label);
  }

  Future<void> deleteFace(int id, String hardwareId) {
    return _faceService.deleteFace(id, hardwareId);
  }

  Future<void> updateFace(int id, String label) {
    return _faceService.updateFace(id, label);
  }
}