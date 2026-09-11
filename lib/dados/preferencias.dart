import 'package:shared_preferences/shared_preferences.dart';

/// Guarda as credenciais somente no aparelho.
///
/// Nada disso vai para o codigo nem para o repositorio.
class Preferencias {
  static const _chaveUrl = 'turso_url';
  static const _chaveToken = 'turso_token';
  static const _chaveDeepseek = 'deepseek_api_key';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> lerUrl() async => (await _prefs).getString(_chaveUrl) ?? '';

  Future<String> lerToken() async =>
      (await _prefs).getString(_chaveToken) ?? '';

  /// Chave da DeepSeek. Ainda nao e usada; fica pronta para a Fase 2.
  Future<String> lerChaveDeepseek() async =>
      (await _prefs).getString(_chaveDeepseek) ?? '';

  Future<void> salvar({
    required String url,
    required String token,
    required String chaveDeepseek,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_chaveUrl, url.trim());
    await prefs.setString(_chaveToken, token.trim());
    await prefs.setString(_chaveDeepseek, chaveDeepseek.trim());
  }
}
