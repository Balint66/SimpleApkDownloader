import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'jwt_gen.dart';

class AuthTokenGen
{
  final JWTGen _jwtgen;
  final HttpClient _client;
  final String _user;
  final String _repo;
  String _token;
  Timer _timer;
  AuthTokenGen(this._jwtgen, this._client, this._user, this._repo);

  Future<String> produce() async
  {
    if(_token == null)
    {
      //Setup the request here for installations
      var request = await _client.getUrl(Uri.https('api.github.com', 'app/installations'));
      request.headers.add('Accept', 'application/vnd.github.v3+json');
      request.headers.add('Authorization', 'Bearer ' + _jwtgen.produce());

      //Get the response and get the installation id
      var response = await request.close();
      var bodys = await response.transform(Utf8Decoder()).fold<String>('',(p, c)=>p+c);
      var body = ((json.decode(bodys))as List<dynamic>).cast<Map<String, dynamic>>();

      //filter for the user
      body.removeWhere((item)=>item['account'] == null || item['account']['url'] == null || !(item['account']['url'].toString()).contains(_user));
      var url = body.first['access_tokens_url'] as String;

      //Now getting the installation token. This expires every hour. (POST must be used!)
      request = await _client.postUrl(Uri.tryParse(url));
      request.headers.add('Accept', 'application/vnd.github.v3+json');
      request.headers.add('Authorization', 'Bearer ' + _jwtgen.produce());

      //let github do here the filtering
      request.write(json.encode(<String, dynamic>{
        'repositories':<String>[_repo]
      }));

      //TODO: test for errors, becuse the repo is not connected to the installation

      //Get response for the token
      response = await request.close();
      bodys = await response.transform(Utf8Decoder()).fold<String>('',(p, c)=>p+c);

      //Setup the token and the timer
      _token = json.decode(bodys)['token'];
      _timer = Timer(Duration(hours: 1), (){_token = null;});
    }
    
    //Return the saved token
    return _token;
  }

}