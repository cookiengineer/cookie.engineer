#!/bin/bash

GO="$(which go 2> /dev/null)";
ROOT="$(pwd)";

if [[ "${ROOT}" == *"/toolchain" ]]; then
	ROOT="${ROOT%%/toolchain}";
elif [[ "${ROOT}" == *"/toolchain/server" ]]; then
	ROOT="${ROOT%%/toolchain/server}";
fi;

if [[ "${GO}" != "" ]]; then

	cd "${ROOT}/toolchain/server";

	go build -o "${ROOT}/toolchain/serve.bin" "${ROOT}/toolchain/server/cmds/serve/main.go";

	if [[ $? == 0 ]]; then

		echo -e "- Build: serve [\e[32mok\e[0m]";

		cd "${ROOT}";
		chmod +x "${ROOT}/toolchain/serve.bin";
		"${ROOT}/toolchain/serve.bin";

	else
		echo -e "- Build: serve [\e[31mfail\e[0m]";
		exit 1;
	fi;

else

	echo -e "Please install go compiler. [\e[31mfail\e[0m]";
	exit 1;

fi;

