#!/bin/bash

# identifiant de l'application pour la freebox
app_id="zabbix.sonde"

# clef publique
track_id=

# clef privee
app_token=

if test -z "${app_token}" ; then

    echo "Le serveur Zabbix doit être sur le réseau de la freebox"
    echo 'Appuyer sur la touche > sur la facade de la freebox'

    reponse=$(curl --silent -k --header "Content-Type: application/json" \
      --request POST \
      --data '{ "app_id": "'${app_id}'", "app_name": "Zabbix", "app_version": "0.1.0", "device_name": "'$(hostname)'"}' \
      https://mafreebox.freebox.fr/api/v4/login/authorize/
    )

    Track_id=${reponse##*track_id}
    Track_id=${Track_id#*:}
    Track_id=${Track_id%%,*}
    Track_id=${Track_id%%\}*}
    Track_id=${Track_id//\"/}
    Track_id=${Track_id//\\/}
    # le script va s'automodifier pour renseigner le track_id
    sed -i "s/^track_id=.*$/track_id=${Track_id}/" ${0}

    App_token=${reponse##*app_token}
    App_token=${App_token#*:}
    App_token=${App_token%%,*}
    App_token=${App_token%%\}*}
    App_token=${App_token//\"/}
    #App_token=${App_token//\\/}  #mis en commentaire pour etre compatible avec le sed en dessous
    # le script va s'automodifier pour renseigner le app_token
    sed -i "s/^app_token=.*$/app_token=${App_token}/" ${0}

    echo "Puis relancer ce script"
    exit 1
fi

success='inconnu'
for i in {1..3} ; do # 3 tentatives de mot de passe
    if test "$success" != "true" ; then

        status='inconnu'
        for i in {1..3} ; do # 3 tentatives de demande du challenge
            if test "${status}" != "pending" -a "${status}" != "granted" ; then
                reponse=$(curl --connect-timeout 2 --max-time 3 --silent -k https://mafreebox.freebox.fr/api/v4/login/authorize/${track_id})

                status=${reponse##*\"status\"}       # efface tout ce qui est present avant le dernier mot recherché "status"
                status=${status#*:}                  # efface tout ce qui est present avant le premier :
                status=${status%%,*}                 # efface de la premiere , jusqu'a la fin de la ligne
                status=${status%%\}*}                # efface de la premiere } jusqu'a la fin de la ligne
                status=${status//\"/}                # efface tous les "
                status=${status//\\/}                # efface tous les \

            fi
        done

        if test "${status}" != "pending" -a "${status}" != "granted" ; then
            # lecture en erreur
            if test -z "${reponse}" ; then
                echo '{"success":false}'
            else
                echo ${reponse}
            fi
            exit 11
        fi

        #############################################################################
        # reponse ok. Recherche du challenge et calcul du mot de passe en utilisant la clef privee

        challenge=${reponse##*\"challenge\"} # efface tout ce qui est present avant le dernier mot recherché "challenge"
        challenge=${challenge#*:}            # efface tout ce qui est present avant le premier :
        challenge=${challenge%%,*}           # efface de la premiere , jusqu'a la fin de la ligne
        challenge=${challenge%%\}*}          # efface de la premiere } jusqu'a la fin de la ligne
        challenge=${challenge//\"/}          # efface tous les "
        challenge=${challenge//\\/}          # efface tous les \

        password=$(/bin/echo -n  ${challenge} | openssl dgst -sha1 -hmac ${app_token})
        password=${password##* }             # efface tout ce qui est avant le dernier espace de la ligne

        reponse=$(curl --connect-timeout 2 --max-time 3 --silent -k --header "Content-Type: application/json" \
          --request POST \
          --data '{ "app_id": "'${app_id}'", "password": "'${password}'" }' \
          https://mafreebox.freebox.fr/api/v4/login/session/
        )

        success=${reponse##*\"success\"}
        success=${success#*:}
        success=${success%%,*}
        success=${success%%\}*}
        success=${success//\"/}
        success=${success//\\/}

    fi
done

if test "${success}" != "true" ; then
    # lecture en erreur
    if test -z "${reponse}" ; then
        echo '{"success":false}'
    else
        echo ${reponse}
    fi
    exit 12
fi

session_token=${reponse##*\"session_token\"}
session_token=${session_token#*:}
session_token=${session_token%%,*}
session_token=${session_token%%\}*}
session_token=${session_token//\"/}
session_token=${session_token//\\/}

reponse=$(curl --connect-timeout 2 --max-time 3 --silent -k -H "X-Fbx-App-Auth: ${session_token}" https://mafreebox.freebox.fr/api/v4/connection/)
if test -z "${reponse}" ; then
    echo '{"success":false}'
    exit 2
else
    echo ${reponse}
fi

exit 0
