#include "DemocratGameMode.h"
#include "DemocratCharacter.h"
#include "DemocratGovernmentBuilding.h"
#include "Engine/World.h"

ADemocratGameMode::ADemocratGameMode()
{
    DefaultPawnClass = ADemocratCharacter::StaticClass();
}

void ADemocratGameMode::BeginPlay()
{
    Super::BeginPlay();

    if (GetWorld())
    {
        GetWorld()->SpawnActor<ADemocratGovernmentBuilding>(
            ADemocratGovernmentBuilding::StaticClass(),
            FVector::ZeroVector,
            FRotator::ZeroRotator
        );
    }
}