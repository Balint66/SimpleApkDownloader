import 'dart:async';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class JWTGen
{
  final JWT _jwt;
  String _jwtString;
  Timer _timer;
  final PrivateKey _privateKey;

  JWTGen(String issuerID, this._privateKey) : _jwt = JWT({'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000}, issuer: issuerID);

  String produce()
  {
    if(_jwtString == null)
    {
      //We are generating the signed jwt here
      _jwtString = _jwt.sign(_privateKey, expiresIn: Duration(minutes: 10),
        algorithm: JWTAlgorithm.RS256, noIssueAt: false);
        //Setting up a timer thatclears the jwt on expiration
      _timer = Timer(Duration(minutes: 10), (){_jwtString = null;});
    }
    return _jwtString;

  }
}