import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oauth2_client/oauth2_response.dart';

/// Represents the response to an Access Token Request.
/// see https://tools.ietf.org/html/rfc6749#section-5.2

class AccessTokenResponse extends OAuth2Response {
  String accessToken;
  String tokenType;
  int expiresIn;
  String refreshToken;
  List<String> scope;
  String userId;

  DateTime expirationDate;

  AccessTokenResponse();

  AccessTokenResponse.fromMap(Map<String, dynamic> map) : super.fromMap(map) {
    if (isValid()) {
      accessToken = map['access_token'];
      tokenType = map['token_type'];
      if (map.containsKey('refresh_token')) refreshToken = map['refresh_token'];

      if (map.containsKey('scope')) {
        if (map['scope'] is List) {
          List scopesJson = map['scope'];
          scope = scopesJson != null ? List.from(scopesJson) : null;
        } else {
          //The OAuth 2 standard suggests that the scopes should be a space-separated list,
          //but some providers (i.e. GitHub) return a comma-separated list
          scope = map['scope'].split(RegExp(r'[\s,]'));
        }

        scope = scope.map((s) => s.trim()).toList();
      }

      //Add support for user_id payload
      if (map.containsKey('user_id')) {
        userId = map['user_id'];
      }

      if (map.containsKey('expires_in')) expiresIn = map['expires_in'];

      expirationDate = null;

      if (map.containsKey('expiration_date') &&
          map['expiration_date'] != null) {
        expirationDate =
            DateTime.fromMillisecondsSinceEpoch(map['expiration_date']);
      } else {
        if (expiresIn != null) {
          var now = DateTime.now();
          expirationDate = now.add(Duration(seconds: expiresIn));
        }
      }
    }
  }

  factory AccessTokenResponse.fromHttpResponse(http.Response response,
      {requestedScopes}) {
    AccessTokenResponse resp;

    if (response.statusCode != 404) {
      Map respMap = jsonDecode(response.body);
      //From Section 4.2.2. (Access Token Response) of OAuth2 rfc, the "scope" parameter in the Access Token Response is
      //"OPTIONAL, if identical to the scope requested by the client; otherwise, REQUIRED."
      if ((!respMap.containsKey('scope') || respMap['scope'].isEmpty) &&
          requestedScopes != null) {
        respMap['scope'] = requestedScopes;
      }
      respMap['http_status_code'] = response.statusCode;

      resp = AccessTokenResponse.fromMap(respMap);
    } else {
      resp = AccessTokenResponse();
      resp.httpStatusCode = response.statusCode;
    }

    return resp;
  }

  @override
  Map<String, dynamic> toMap() {
    var now = DateTime.now();

    return {
      'http_status_code': httpStatusCode,
      'access_token': accessToken,
      'token_type': tokenType,
      'refresh_token': refreshToken,
      'scope': scope,
      'expires_in': expirationDate != null
          ? expirationDate.difference(now).inSeconds
          : null,
      'expiration_date':
          expirationDate != null ? expirationDate.millisecondsSinceEpoch : null,
      'error': error,
      'errorDescription': errorDescription,
      'errorUri': errorUri
    };
  }

  ///Checks if the access token is expired
  bool isExpired() {
    var expired = false;

    if (expirationDate != null) {
      var now = DateTime.now();
      expired = expirationDate.difference(now).inSeconds < 0;
    }

    return expired;
  }

  ///Checks if the access token must be refreeshed
  bool refreshNeeded({secondsToExpiration = 30}) {
    var needsRefresh = false;

    if (expirationDate != null) {
      var now = DateTime.now();
      needsRefresh =
          expirationDate.difference(now).inSeconds < secondsToExpiration;
    }

    return needsRefresh;
  }

  ///Checks if the refresh token has been returned by the server
  bool hasRefreshToken() {
    return refreshToken != null;
  }

  ///Checks if the token is a "Bearer" token
  bool isBearer() {
    return tokenType.toLowerCase() == 'bearer';
  }

  @override
  String toString() {
    if (httpStatusCode == 200) {
      return 'Access Token: ' + accessToken;
    } else {
      return 'HTTP ' +
          httpStatusCode.toString() +
          ' - ' +
          (error ?? '') +
          ' ' +
          (errorDescription ?? '');
    }
  }
}
