#!/usr/bin/env python3
"""Compara a versão do Firefox do último release do ColdFox com a mais recente da Mozilla.

Lê as notas do último release (tabela gerada por scripts/release-assets.sh, com
"Firefox <versão>" por arquivo) e as versões atuais (JSON de product-details da Mozilla).
Escreve no stdout, no formato do $GITHUB_OUTPUT:
  nova=true|false   há versão nova do ESR (desktop) ou da estável (Android)
  tag=vX.Y          próxima tag (último release com o número do meio + 1)
  resumo=...        o que mudou, numa linha
Uso: versao-nova.py <tag-atual> <notas.md> <firefox_versions.json>
"""
import json
import re
import sys


def chave(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    tag, notas, atuais = sys.argv[1], open(sys.argv[2]).read(), json.load(open(sys.argv[3]))
    m = re.fullmatch(r"v(\d+)\.(\d+)(?:\.\d+)?", tag)
    if not m:
        sys.exit(f"tag inesperada: {tag}")
    proxima = f"v{m[1]}.{int(m[2]) + 1}"

    def publicada(plataforma):
        achou = re.findall(rf"coldfox-{plataforma}-[^`]*`.*?Firefox ([0-9.]+)", notas)
        return max(achou, key=chave) if achou else None

    mudou = []
    for nome, plataforma, chave_json in (("desktop", "linux", "FIREFOX_ESR"), ("Android", "android", "LATEST_FIREFOX_VERSION")):
        nova = re.sub(r"esr$", "", atuais[chave_json])
        velha = publicada(plataforma)
        # Notas sem a tabela (releases antigos): trata como desatualizado.
        if velha is None or chave(nova) > chave(velha):
            mudou.append(f"{nome} {velha or '?'} → {nova}")
    print(f"nova={'true' if mudou else 'false'}")
    print(f"tag={proxima}")
    print(f"resumo=Firefox {', '.join(mudou) if mudou else 'sem novidade'}")


if __name__ == "__main__":
    main()
