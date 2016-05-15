#!/bin/sh
# Copyright (C) 2013-2015 Sören Tempel
# Copyright (C) 2016 Klemens Nanni <kl3@posteo.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

umask 077

## Variables

GPG_OPTS='--quiet --yes --batch'
STORE_DIR="${PASSWORD_STORE_DIR:-${HOME}/.tpm}"

if [ -z "${PASSWORD_STORE_KEY}" ]; then
	GPG_OPTS="${GPG_OPTS} --default-recipient-self"
else
	GPG_OPTS="${GPG_OPTS} --recipient ${PASSWORD_STORE_KEY}"
fi

## Helper

abort() {
	printf '%s\n' "${1}" 1>&2
	exit 1
}

readpw() {
	if [ -t 0 ]; then
		printf '%s' "${1}"
		stty -echo
	fi

	IFS= read -r "${2}"
	[ -t 0 ] && stty echo
}

## Commands

insert() {
	[ -z "${1}" ] && abort 'Name must not be empty.'
	[ -e "${STORE_DIR}"/"${1}".gpg ] && abort 'Entry already exists.'

	readpw "Password for '${1}': " password
	[ -t 0 ] && printf '\n'

	[ -z "${password}" ] && abort 'No password specified.'

	mkdir -p "$(dirname "${STORE_DIR}"/"${1}".gpg)"
	printf '%s\n' "${password}" \
		| gpg2 ${GPG_OPTS} --encrypt --output "${STORE_DIR}"/"${1}".gpg
}

list() {
	[ -d "${STORE_DIR}" ] || mkdir -p "${STORE_DIR}"

	[ -n "${1}" ] && [ ! -d "${STORE_DIR}/${1}" ] \
		&& abort "No such group. See 'tpm list'."

	tree --noreport -l -C -- "${STORE_DIR}/${1}" \
		| sed 's/.gpg$//g'
	printf '\n'
}

remove() {
	[ -z "${1}" ] && abort 'Name must not be empty.'
	[ -w "${STORE_DIR}"/"${1}".gpg ] || abort 'No such entry.'

	rm -i "${STORE_DIR}"/"${1}".gpg
}

show() {
	[ -z "${1}" ] && abort 'Name must not be empty.'

	entry="${STORE_DIR}"/"${1}".gpg

	if [ ! -r "${entry}" ]; then
		entry=$(find "${STORE_DIR}" -type f -iwholename "*${1}*".gpg)

		[ -z "${entry}" ] && abort 'No such entry.'

		[ "$(printf '%s' "${entry}" | wc -l)" -gt 0 ] \
			&& abort 'Too ambigious keyword.'
	fi

	gpg2 ${GPG_OPTS} --decrypt "${entry}"
}

## Parse input

[ ${#} -eq 0 ] || [ ${#} -gt 2 ] \
	&& abort "Invalid number of arguments. See 'tpm help'."

case "${1}" in
	insert|list|remove|show)
		${1}    "${2}"
		;;
	help)
		cat <<- EOF
		USAGE:	tpm show|insert|list|help [ENTRY|GROUP]

		See tpm(1) for more information.
		EOF
		;;
	*)
		abort   "Invalid command. See 'tpm help'."
		;;
esac
