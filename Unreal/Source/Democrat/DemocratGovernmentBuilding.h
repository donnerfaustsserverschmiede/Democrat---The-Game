#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DemocratGovernmentBuilding.generated.h"

UCLASS()
class DEMOCRAT_API ADemocratGovernmentBuilding : public AActor
{
    GENERATED_BODY()

public:
    ADemocratGovernmentBuilding();

protected:
    virtual void OnConstruction(const FTransform& Transform) override;

private:
    UPROPERTY()
    TObjectPtr<USceneComponent> Root;

    UPROPERTY()
    TObjectPtr<UStaticMesh> CubeMesh;

    void AddBlock(const FVector& Location, const FVector& Scale, const FString& Label);
    void AddRoom(const FVector& Center, const FVector& Size, const FString& Label);
};