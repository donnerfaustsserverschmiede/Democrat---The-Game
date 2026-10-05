#include "DemocratGameMode.h"
#include "DemocratCharacter.h"

ADemocratGameMode::ADemocratGameMode()
{
    DefaultPawnClass = ADemocratCharacter::StaticClass();
}