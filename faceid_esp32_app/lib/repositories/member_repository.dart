import '../models/user_model.dart';
import '../models/join_request_model.dart'; // Thêm import
import '../services/member_service.dart';

class MemberRepository {
  final MemberService _memberService;

  MemberRepository(this._memberService);

  Future<List<UserModel>> getAllMembers() {
    return _memberService.getAllMembers();
  }

  // Thêm hàm lấy danh sách yêu cầu
  Future<List<JoinRequestModel>> getJoinRequests() {
    return _memberService.getJoinRequests();
  }

  Future<bool> acceptRequest(int requesterId) {
    return _memberService.acceptRequest(requesterId);
  }

  Future<bool> removeMember(int memberId) {
    return _memberService.removeMember(memberId);
  }
}