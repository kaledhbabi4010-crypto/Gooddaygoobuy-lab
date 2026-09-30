# GOODDAY220 Windows Real Lab

Run ID: 20260930T185737Z

## Current phase

This repository currently builds and verifies the Windows BASE only.

Included:

- Windows runtime
- PowerShell
- Python
- pip
- Git
- .NET
- CMake
- MSVC detection
- Windows SDK detection
- 7-Zip detection
- hardware inventory
- network evidence
- administrator evidence
- structured evidence
- future module architecture

Not installed in this phase:

- Goodday
- AutoCAD
- Revit

The application source repository is not used by this phase.

## Future modules

Future software is represented as independent modules:

- goodday
- autocad
- revit

They do NOT need to be installed together.

The intended lifecycle is:

    BASE
      |
      +-- install module A
      |
      +-- verify module A
      |
      +-- install module B
      |
      +-- verify module B
      |
      +-- remove module A if required

The base environment does not need to be rebuilt after every module.

## Persistence

The GitHub-hosted Windows runner is used for real runtime verification,
but GitHub-hosted runners are ephemeral.

The PowerShell bootstrap under:

    scripts/windows/bootstrap.ps1

is therefore designed so that the same base can later be installed on
a persistent Windows VM/self-hosted runner.

## Security

The GitHub token used by the Colab controller is never placed in this
repository and never passed into the Windows workflow.

## Evidence

All runtime evidence is written under:

    evidence/

No result is marked RUNTIME_CONFIRMED merely because a file exists.
The Windows machine must actually execute the corresponding command.
