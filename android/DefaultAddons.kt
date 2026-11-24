/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

package org.mozilla.fenix.cleanfox

import android.content.Context
import mozilla.components.concept.engine.webextension.InstallationMethod
import mozilla.components.concept.engine.webextension.PermissionPromptResponse
import mozilla.components.concept.engine.webextension.WebExtension
import mozilla.components.feature.addons.AddonManager
import mozilla.components.support.base.log.logger.Logger
import mozilla.components.support.webextensions.WebExtensionSupport
import java.util.Collections

/**
 * CleanFox: instala as extensões de fábrica (as mesmas do desktop, em settings/policies.json)
 * da loja da Mozilla. Cada uma é instalada uma única vez: se o usuário removê-la, não volta.
 * Sem rede na primeira abertura, tenta de novo nas próximas.
 *
 * Só as instalações iniciadas aqui são aprovadas sem diálogo, e só se a extensão baixada
 * tiver o ID esperado; qualquer outra continua pedindo permissão ao usuário.
 */
object DefaultAddons {
    private val ADDONS = mapOf(
        "uBlock0@raymondhill.net" to
            "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi",
        "jid1-MnnxcxisBPnSXQ@jetpack" to
            "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi",
        "jid1-BoFifL9Vbdl2zQ@jetpack" to
            "https://addons.mozilla.org/firefox/downloads/latest/decentraleyes/latest.xpi",
    )
    private const val PREFS = "cleanfox_default_addons"
    private val logger = Logger("CleanFoxDefaultAddons")
    private val pending: MutableSet<String> = Collections.synchronizedSet(mutableSetOf())

    fun installIfNeeded(context: Context, addonManager: AddonManager, installed: List<WebExtension>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val installedIds = installed.map { it.id }.toSet()

        WebExtensionSupport.installPermissionInterceptor = { extension ->
            if (extension.id in pending) {
                PermissionPromptResponse(isPermissionsGranted = true, isPrivateModeGranted = true)
            } else {
                null
            }
        }

        for ((id, url) in ADDONS) {
            if (prefs.getBoolean(id, false)) continue
            if (id in installedIds) {
                prefs.edit().putBoolean(id, true).apply()
                continue
            }
            if (!pending.add(id)) continue
            addonManager.installAddon(
                url = url,
                installationMethod = InstallationMethod.MANAGER,
                onSuccess = {
                    prefs.edit().putBoolean(id, true).apply()
                    pending.remove(id)
                },
                onError = { e ->
                    pending.remove(id)
                    logger.warn("Falha ao instalar $id; nova tentativa na próxima abertura", e)
                },
            )
        }
    }
}
