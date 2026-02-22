import '../../core/extensions/map_x.dart';

class Room {
  final String? idRoom;
  final String? roomName;
  final int? floor;
  final String? block;

  Room({this.idRoom, this.roomName, this.floor, this.block});

  static Room fromJson(Map<String, dynamic> json) {
    return Room(
      idRoom: json['id']?.toString(),
      roomName: (json['roomName'] ?? json['room_name'])?.toString(),
      floor: json.parseInt('floor'),
      block: json['block']?.toString(),
    );
  }
}
