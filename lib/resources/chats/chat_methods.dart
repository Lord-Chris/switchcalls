import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:switchcalls/constants/strings.dart';
import 'package:switchcalls/models/chat.dart';
import 'package:switchcalls/models/contact.dart';
import 'package:switchcalls/models/message.dart';
import 'package:switchcalls/models/user.dart';

abstract class IMessages {
  Stream chatList(String userId, String recipientId);
  Stream unReadMessages(String userId);
  void messageList(QuerySnapshot data, StreamController cont);
  Future sendMessage({Message message});
}

class ChatMethods extends IMessages {
  static final Firestore _firestore = Firestore.instance;

  final CollectionReference _messageCollection =
      _firestore.collection(MESSAGES_COLLECTION);

  final CollectionReference _userCollection =
      _firestore.collection(USERS_COLLECTION);

  Stream<QuerySnapshot> chatDB(String userId) =>
      _messageCollection.document(userId).collection('chats').snapshots();

  Future<QuerySnapshot> usersDB(String userId) =>
      _userCollection.getDocuments();

  @override
  Stream<List<Message>> chatList(String userId, String recipientId) {
    // print('Info is $userId, $recipientId');
    return _messageCollection
        .document(userId)
        .collection('chats')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .transform(transformer(recipientId));
  }

  @override
  void messageList(QuerySnapshot data, StreamController cont) {
    try {
      List<Chat> chats = [];

      data.documents.forEach((doc) {
        List<String> chaIdList = doc.documentID.split(' ');
        String userId = chaIdList[0];
        String timeInMS = chaIdList[1];

        if (chats.where((element) => element.uid == userId) == null) {
          chats.add(Chat(
            uid: userId,
            timeInMS: int.parse(timeInMS),
            lastMessage: doc.data['message'],
          ));
        } else {
          chats.removeWhere((element) => element.uid == userId);
          chats.add(Chat(
            uid: userId,
            timeInMS: int.parse(timeInMS),
            lastMessage: doc.data['message'],
          ));
        }
      });
      // print(chats);

      chats.sort((a, b) {
        DateTime first = a?.time ?? DateTime.utc(2018);
        DateTime second = b?.time ?? DateTime.utc(2018);
        return second.compareTo(first);
      });

      if (!cont.isClosed) cont.add(chats);
    } catch (e) {
      print('Message List Error: ${e.toString()}');
    }
  }

  @override
  Future<void> sendMessage({Message message}) async {
    Map<String, dynamic> map = message.toMap();
    Timestamp _time = Timestamp.now();

    map['isRead'] = true;
    map['isSender'] = true;
    await _messageCollection
        .document(message.senderId)
        .collection('chats')
        .document('${message.receiverId} ${_time.microsecondsSinceEpoch}')
        .setData(map);

    // add receiver to sender's contacts list
    addToContacts(message.senderId, message.receiverId, _time);
    // add sender to receiver's contacts list
    addToContacts(message.receiverId, message.senderId, _time);

    map['isRead'] = false;
    map['isSender'] = false;
    return await _messageCollection
        .document(message.receiverId)
        .collection('chats')
        .document('${message.senderId} ${_time.microsecondsSinceEpoch}')
        .setData(map);
  }

  @override
  Stream unReadMessages(String userId) {
    try {
      Stream<int> number = _messageCollection
          .document(userId)
          .collection('chats')
          .where('isSender', isEqualTo: false)
          .where('senderId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .transform(new StreamTransformer<QuerySnapshot, int>.fromHandlers(
        handleData: (QuerySnapshot data, EventSink<int> sink) {
          // print(data.docs.length);
          sink.add(data.documents.length);
        },
      ));
      return number;
    } catch (e) {
      print('Unread Messages error: ' + e.toString());
      throw Exception(e);
    }
  }

  void setImageMsg(String url, String receiverId, String senderId) async {
    Message message;

    message = Message.imageMessage(
        message: "IMAGE",
        receiverId: receiverId,
        senderId: senderId,
        photoUrl: url,
        timestamp: Timestamp.now(),
        type: 'image');

    await sendMessage(message: message);
  }

  Stream<List<User>> fetchContacts({String userId}) {
    return _userCollection.snapshots().transform(contactTrans());
  }

  Future<void> addToContacts(
      String userId, String idToAdd, Timestamp currentTime) async {
    DocumentSnapshot senderSnapshot =
        await getContactsDocument(of: userId, forContact: idToAdd).get();
    if (!senderSnapshot.exists) {
      //does not exists
      Contact receiverContact = Contact(uid: idToAdd, addedOn: currentTime);

      var receiverMap = receiverContact.toMap(receiverContact);

      await getContactsDocument(of: userId, forContact: idToAdd)
          .setData(receiverMap);
    }
  }

  DocumentReference getContactsDocument({String of, String forContact}) {
    return _userCollection
        .document(of)
        .collection(CONTACTS_COLLECTION)
        .document(forContact);
  }

  // UTILITIES
  StreamTransformer<QuerySnapshot, List<Message>> transformer(
      String recipientId) {
    return StreamTransformer<QuerySnapshot, List<Message>>.fromHandlers(
      handleData: (QuerySnapshot data, EventSink<List<Message>> sink) {
        final chats = data.documents
            .where((element) => element.documentID.startsWith(recipientId))
            .toList();
        List<Message> formattedChats =
            chats.map((chat) => convertToMessage(chat, recipientId)).toList();
        sink.add(formattedChats);
      },
    );
  }

  StreamTransformer<QuerySnapshot, List<User>> contactTrans() {
    return StreamTransformer<QuerySnapshot, List<User>>.fromHandlers(
      handleData: (data, sink) {
        List<User> list = data.documents.map((e) => User.fromMap(e.data)).toList();
        sink.add(list);
      },
    );
  }

  Message convertToMessage(DocumentSnapshot chat, String recipientId) {
    // _storedb.readMessage(chat, recipientId);
    return Message(
      receiverId: chat.data['receiverId'],
      senderId: chat.data['senderId'],
      message: chat.data['message'],
      type: chat.data['type'],
      timestamp: chat.data['timestamp'],
    );
  }
}

// class ChatMethods {
//   static final Firestore _firestore = Firestore.instance;

//   final CollectionReference _messageCollection =
//   _firestore.collection(MESSAGES_COLLECTION);

//   final CollectionReference _userCollection =
//   _firestore.collection(USERS_COLLECTION);

//   Future<void> addMessageToDb(
//       Message message, User sender, User receiver) async {
//     var map = message.toMap();

//     await _messageCollection
//         .document(message.senderId)
//         .collection(message.receiverId)
//         .add(map);

//     addToContacts(senderId: message.senderId, receiverId: message.receiverId);

//     return await _messageCollection
//         .document(message.receiverId)
//         .collection(message.senderId)
//         .add(map);
//   }

//   DocumentReference getContactsDocument({String of, String forContact}) =>
//       _userCollection
//           .document(of)
//           .collection(CONTACTS_COLLECTION)
//           .document(forContact);

//   addToContacts({String senderId, String receiverId}) async {
//     Timestamp currentTime = Timestamp.now();

//     await addToSenderContacts(senderId, receiverId, currentTime);
//     await addToReceiverContacts(senderId, receiverId, currentTime);
//   }

//   Future<void> addToSenderContacts(
//       String senderId,
//       String receiverId,
//       currentTime,
//       ) async {
//     DocumentSnapshot senderSnapshot =
//     await getContactsDocument(of: senderId, forContact: receiverId).get();

//     if (!senderSnapshot.exists) {
//       //does not exists
//       Contact receiverContact = Contact(
//         uid: receiverId,
//         addedOn: currentTime,
//       );

//       var receiverMap = receiverContact.toMap(receiverContact);

//       await getContactsDocument(of: senderId, forContact: receiverId)
//           .setData(receiverMap);
//     }
//   }

//   Future<void> addToReceiverContacts(
//       String senderId,
//       String receiverId,
//       currentTime,
//       ) async {
//     DocumentSnapshot receiverSnapshot =
//     await getContactsDocument(of: receiverId, forContact: senderId).get();

//     if (!receiverSnapshot.exists) {
//       //does not exists
//       Contact senderContact = Contact(
//         uid: senderId,
//         addedOn: currentTime,
//       );

//       var senderMap = senderContact.toMap(senderContact);

//       await getContactsDocument(of: receiverId, forContact: senderId)
//           .setData(senderMap);
//     }
//   }

//   Stream<QuerySnapshot> fetchContacts({String userId}) => _userCollection
//       .document(userId)
//       .collection(CONTACTS_COLLECTION)
//       // .orderBy(_userCollection.document(userId).collection(CONTACTS_COLLECTION).document("timestamp"))
//       .snapshots();

//   Stream<QuerySnapshot> fetchLastMessageBetween({
//     @required String senderId,
//     @required String receiverId,
//   }) =>
//       _messageCollection
//           .document(senderId)
//           .collection(receiverId)
//           .orderBy("timestamp")
//           .snapshots();
// }