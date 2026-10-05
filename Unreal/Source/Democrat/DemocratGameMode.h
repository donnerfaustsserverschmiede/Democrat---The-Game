#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "DemocratGameMode.generated.h"

UCLASS()
class DEMOCRAT_API ADemocratGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    ADemocratGameMode();
    virtual void BeginPlay() override;
};