#!/bin/bash

if [ -z "$NAME" ] || [ -z "$NS" ] || [ -z "$CHART" ] || [ -z "$VALUES" ] || [ -z "$VERSION" ]; then

    echo "To use this script you should define the following variables and call '../chartInstaller.sh \$1':"
    echo "  NAME      the name to give the release, and the name of the yaml file with chart configuration"
    echo "  NS        namespace where to deploy this chart"
    echo "  CHART     name of the char (with folder: stable/somechart)"
    echo "  VALUES    yaml file containing values"
    echo "  VERSION   specific chart version to install. Use 'helm search \$CHART' to see existing versions"
    exit 1
fi

case $1 in
debug)
    helm install --debug --dry-run --name ${NAME} --namespace ${NS} -f ${VALUES} ${CHART} > ${NAME}-debug.yaml
    echo Check ouput at ${NAME}-debug.yaml
    ;;

install)

    helm install  --name ${NAME} --namespace ${NS} -f ${VALUES} --version ${VERSION} ${CHART}

    echo "Installed ${NAME}"
    ;;

update)

    helm upgrade ${NAME} --namespace ${NS} -f ${VALUES} --version ${VERSION}  ${CHART}
    echo "Updated ${NAME}"
    ;;

*)
  echo "Use: chartInstaller.sh [install|update|debug]"
  ;;
esac
