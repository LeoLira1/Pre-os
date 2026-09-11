import 'package:shared_preferences/shared_preferences.dart';

import '../core/custo.dart';

/// Guarda as credenciais e as preferencias somente no aparelho.
///
/// Nada disso vai para o codigo nem para o repositorio.
class Preferencias {
  static const _chaveUrl = 'turso_url';
  static const _chaveToken = 'turso_token';
  static const _chaveDeepseek = 'deepseek_api_key';
  static const _chaveRaciocinio = 'deepseek_raciocinio';
  static const _chavePrecoEntrada = 'preco_entrada_sem_cache';
  static const _chavePrecoCache = 'preco_entrada_com_cache';
  static const _chavePrecoSaida = 'preco_saida';
  static const _chavePicoDobra = 'pico_dobra';
  static const _chaveUltimaLoja = 'ultima_loja';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String> lerUrl() async => (await _prefs).getString(_chaveUrl) ?? '';

  Future<String> lerToken() async =>
      (await _prefs).getString(_chaveToken) ?? '';

  /// Chave da API usada para ler as fotos do tabloide.
  Future<String> lerChaveDeepseek() async =>
      (await _prefs).getString(_chaveDeepseek) ?? '';

  /// Modo de raciocinio do modelo. Desligado por padrao: mais barato.
  Future<bool> lerRaciocinio() async =>
      (await _prefs).getBool(_chaveRaciocinio) ?? false;

  Future<void> salvarRaciocinio(bool ligado) async =>
      (await _prefs).setBool(_chaveRaciocinio, ligado);

  /// Ultima loja usada numa importacao por foto, para vir preenchida.
  Future<String> lerUltimaLoja() async =>
      (await _prefs).getString(_chaveUltimaLoja) ?? '';

  Future<void> salvarUltimaLoja(String loja) async =>
      (await _prefs).setString(_chaveUltimaLoja, loja.trim());

  Future<TabelaPrecos> lerPrecos() async {
    final prefs = await _prefs;
    const padrao = TabelaPrecos();
    return TabelaPrecos(
      entradaSemCache:
          prefs.getDouble(_chavePrecoEntrada) ?? padrao.entradaSemCache,
      entradaComCache:
          prefs.getDouble(_chavePrecoCache) ?? padrao.entradaComCache,
      saida: prefs.getDouble(_chavePrecoSaida) ?? padrao.saida,
      picoDobra: prefs.getBool(_chavePicoDobra) ?? padrao.picoDobra,
    );
  }

  Future<void> salvarPrecos(TabelaPrecos precos) async {
    final prefs = await _prefs;
    await prefs.setDouble(_chavePrecoEntrada, precos.entradaSemCache);
    await prefs.setDouble(_chavePrecoCache, precos.entradaComCache);
    await prefs.setDouble(_chavePrecoSaida, precos.saida);
    await prefs.setBool(_chavePicoDobra, precos.picoDobra);
  }

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
