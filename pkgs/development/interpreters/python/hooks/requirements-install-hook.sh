# Setup hook for requirements.
echo "Sourcing requirements-install-hook"

declare -a pipInstallFlags

requirementsInstallPhase() {
    echo "Executing requirementsInstallPhase"
    runHook preInstall

    mkdir -p "$out/dist"

    @pythonInterpreter@ -m pip install --prefix="$out" --no-cache $pipInstallFlags

    runHook postInstall
    echo "Finished executing requirementsInstallPhase"
}

if [ -z "${dontUseRequirementsInstall-}" ] && [ -z "${installPhase-}" ]; then
    echo "Using requirementsInstallPhase"
    installPhase=requirementsInstallPhase
fi
