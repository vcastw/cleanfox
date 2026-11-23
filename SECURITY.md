# Segurança do CleanFox

## Reportar uma vulnerabilidade

**Não abra issue pública.** Use o relato privado do GitHub: aba **Security** →
**Report a vulnerability**. Responderemos assim que possível.

Falhas do próprio Firefox (motor, JavaScript, rede) devem ser reportadas à Mozilla em
<https://www.mozilla.org/security/>; o CleanFox recebe a correção ao atualizar a base.
Aqui cabem falhas do que o CleanFox muda: configuração, extensões de fábrica, scripts de
build, CI e releases.

## Controles e o que prova cada um

| Fronteira | Controle | Prova |
|---|---|---|
| Código-fonte do Firefox baixado | `SHA512SUMS` assinado pela chave de release da Mozilla, guardada em `keys/` com impressão digital fixada em `scripts/fetch.sh`; depois SHA-512 do tarball. Falha fechado. | Testado manualmente: `SHA512SUMS` adulterado e assinatura válida de outra chave são recusados. `tests/lint.sh` confere que `keys/` é a chave fixada. |
| CI e releases | Actions fixadas por SHA; permissões mínimas (`contents: read`); só o job de release escreve. Assinatura do APK em job separado, sem código de terceiros, no ambiente `release`. Releases com atestado de procedência (Sigstore). | `tests/lint.sh` recusa action sem SHA. Conferir um download: `gh attestation verify <arquivo> -R vcastw/cleanfox`. |
| Coleta de dados | Telemetria, estudos, relatórios de falha e atribuição de anúncios desligados e travados; código de envio de telemetria e crash reporter fora da compilação. | `tests/check-runtime.py` sobe o navegador e confere cada pref (e trava) e política. |
| Conexões em segundo plano | Só hosts listados, com motivo, em `tests/allowed-hosts.txt`. | `tests/check-network.py` registra toda conexão de um perfil novo parado por 2 min e falha com host desconhecido. Roda no CI. |
| Extensões de fábrica | uBlock Origin, Privacy Badger e Decentraleyes da AMO, com assinatura da Mozilla obrigatória; usuário pode removê-las. | `tests/check-extensions.py` confere instaladas, ativas, assinadas e liberadas em janela privativa. |
| Fixação de certificados | Modo estrito (`security.cert_pinning.enforcement_level = 2`): domínios da Mozilla recusam até CAs instaladas manualmente. | `tests/check-runtime.py` (valor da pref). Comprovado na prática: um proxy que intercepta TLS não consegue se passar por `addons.mozilla.org`. |

## Lacunas conhecidas

- **Sem atualizador automático.** O maior risco: o CleanFox só recebe correções de
  segurança quando um release novo é publicado e instalado. Ainda não há releases.
- **Google Safe Browsing desligado.** Menos proteção contra phishing e malware; as listas
  do uBlock Origin cobrem só parte.
- **Downloads da Mozilla dependem da Mozilla.** A chave em `keys/` é a raiz de confiança:
  se a Mozilla trocá-la, a compilação para até alguém conferir a nova chave por outro canal.
- **MozillaBuild (Windows) sem hash fixo.** O job do Windows baixa a versão "Latest" do
  instalador sem conferir hash. A compilação de Windows nunca foi executada.
- **Ambiente `release` sem regra de proteção.** O workflow já usa o ambiente; restringi-lo
  a tags `v*` (e exigir aprovação) é configuração do repositório, em Settings > Environments.
- **Windows e macOS sem assinatura de código**; Android sem chave de release definida.
- **Android:** sem políticas (`policies.json` não existe lá); extensões, buscador e Safe
  Browsing ainda não são ajustados; nunca compilado.
- **Proxies corporativos que inspecionam TLS** não conseguem acessar domínios da Mozilla
  (efeito do modo estrito de fixação). Contorno consciente: mudar a pref para `1`.

## Antes de cada release (tag `v*`)

1. `tests/lint.sh` sem erros.
2. No binário de cada plataforma testável: `tests/check-runtime.py`,
   `tests/check-extensions.py` e `tests/check-network.py`.
3. Base do Firefox na versão mais recente com correções de segurança (`version`, `version-android`).
4. Revisão com a skill `security-audit` do que mudou desde o último release
   (`git diff <tag-anterior>`), com foco em `scripts/`, `.github/workflows/` e `settings/`.
5. Depois de publicar: `gh attestation verify` em um arquivo de cada plataforma.
