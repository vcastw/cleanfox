# Segurança do ColdFox

## Reportar uma vulnerabilidade

**Não abra issue pública.** Use o relato privado do GitHub: aba **Security** →
**Report a vulnerability**. Responderemos assim que possível.

Falhas do próprio Firefox (motor, JavaScript, rede) devem ser reportadas à Mozilla em
<https://www.mozilla.org/security/>; o ColdFox recebe a correção ao atualizar a base.
Aqui cabem falhas do que o ColdFox muda: configuração, extensões de fábrica, scripts de
build, CI e releases.

## Controles e o que prova cada um

| Fronteira | Controle | Prova |
|---|---|---|
| Código-fonte do Firefox baixado | `SHA512SUMS` assinado pela chave de release da Mozilla, guardada em `keys/` com impressão digital fixada em `scripts/fetch.sh`; depois SHA-512 do tarball. Falha fechado. | Testado manualmente: `SHA512SUMS` adulterado e assinatura válida de outra chave são recusados. `tests/lint.sh` confere que `keys/` é a chave fixada. |
| CI e releases | Actions fixadas por SHA; permissões mínimas (`contents: read`); só o job de release escreve. Assinatura do APK em job separado, sem código de terceiros, no ambiente `release`; release sem a chave do projeto ou com APK em chave de debug é recusado (`release-check` e a conferência com `apksigner verify`). Releases com atestado de procedência (Sigstore), publicados por tag `v*` ou por disparo manual com `release_tag` (nome validado, passado por variável de ambiente); o job de release baixa só os artefatos finais (`coldfox-*`), confere o `.sha256` de cada um antes de renomear (`scripts/release-assets.sh`) e publica o release só depois de enviar todos os arquivos. | `tests/lint.sh` recusa action sem SHA, entrada de disparo interpolada em `run:` e artefato não assinado que case com `coldfox-*`; `tests/lint.sh` também exige que o release dependa de `release-check`; `tests/test-release.sh` confere que pacote adulterado, sem `.sha256` ou release incompleto são recusados. Conferir um download: `gh attestation verify <arquivo> -R vcastw/coldfox`. |
| Coleta de dados | Telemetria, estudos, relatórios de falha e atribuição de anúncios desligados e travados; código de envio de telemetria e crash reporter fora da compilação. | `tests/check-runtime.py` sobe o navegador e confere cada pref (e trava) e política. |
| Conexões em segundo plano | Só hosts listados, com motivo, em `tests/allowed-hosts.txt`. | `tests/check-network.py` registra toda conexão de um perfil novo parado por 2 min e falha com host desconhecido. Roda no CI. |
| Extensões de fábrica | uBlock Origin, Privacy Badger e Decentraleyes da AMO, com assinatura da Mozilla obrigatória; usuário pode removê-las. | `tests/check-extensions.py` confere instaladas, ativas, assinadas e liberadas em janela privativa. |
| Fixação de certificados | Modo estrito (`security.cert_pinning.enforcement_level = 2`): domínios da Mozilla recusam até CAs instaladas manualmente. | `tests/check-runtime.py` (valor da pref). Comprovado na prática: um proxy que intercepta TLS não consegue se passar por `addons.mozilla.org`. |
| Atraso nas correções de segurança | `.github/workflows/versao-nova.yml` confere todo dia a versão do Firefox do último release contra a da Mozilla e abre issue (ou dispara o release, com `AUTO_RELEASE=true`). | `tests/test-release.sh` cobre a comparação de versões e a próxima tag. |
| Binários a menos | `pingsender` (envio de telemetria ao fechar) fora da compilação (`patches/0002`); `application.ini` com `Vendor=ColdFox`. | `scripts/package.sh` recusa o pacote Linux com `pingsender` ou outro Vendor (`tests/test-package.sh`). |

## Lacunas conhecidas

- **Sem atualizador automático.** O maior risco: o ColdFox só recebe correções de
  segurança quando um release novo é publicado e instalado. O aviso diário de versão nova
  encurta o atraso do lado do projeto, mas o usuário ainda precisa instalar por conta própria.
  Com `AUTO_RELEASE=true`, um release sai sem revisão humana (os controles do código-fonte
  e do CI continuam valendo).
- **Google Safe Browsing desligado.** Menos proteção contra phishing e malware; as listas
  do uBlock Origin cobrem só parte.
- **Downloads da Mozilla dependem da Mozilla.** A chave em `keys/` é a raiz de confiança:
  se a Mozilla trocá-la, a compilação para até alguém conferir a nova chave por outro canal.
- **MozillaBuild (Windows) sem hash fixo.** O job do Windows baixa a versão "Latest" do
  instalador sem conferir hash.
- **Instalador do Linux (`scripts/install-linux.sh`).** O SHA-256 vem do mesmo release
  que o pacote: pega download corrompido, não um release adulterado. Isso só o atestado
  de procedência pega, e o script só o confere quando há o `gh` autenticado (avisa quando
  não confere). O caminho de download do script não tem teste automático.
- **Ambiente `release` sem regra de proteção.** O workflow já usa o ambiente; restringi-lo
  (exigir aprovação; aceitar só `main` e tags `v*`) é configuração do repositório, em
  Settings > Environments. O release por disparo manual roda a partir da `main`.
- **Windows e macOS sem assinatura de código** (dependem de certificado pago ou de aprovação; README, Assinatura). O atestado de procedência cobre a origem, mas o sistema operacional não o confere.
- **Chave do Android é um arquivo num secret.** Fica no ambiente `release`, que ainda não tem regra de proteção (abaixo): quem puder alterar um workflow na `main` consegue usá-la. A recusa de chave de debug só roda de verdade no CI, num release.
- **Android:** os ajustes são edições no código do Fenix (`scripts/prepare-android.sh`) e
  não há teste automático de runtime (rede, extensões) num aparelho ou emulador. As
  extensões de fábrica são aprovadas sem diálogo só quando o app as pediu e o ID baixado
  confere (`android/DefaultAddons.kt`).
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
