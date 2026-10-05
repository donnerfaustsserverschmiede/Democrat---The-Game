#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "DemocratCharacter.generated.h"

class UCameraComponent;
class USpringArmComponent;

UCLASS()
class DEMOCRAT_API ADemocratCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ADemocratCharacter();

protected:
    virtual void BeginPlay() override;

public:
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;

private:
    UPROPERTY(VisibleAnywhere)
    TObjectPtr<USpringArmComponent> CameraBoom;

    UPROPERTY(VisibleAnywhere)
    TObjectPtr<UCameraComponent> FollowCamera;

    void MoveForward(float Value);
    void MoveRight(float Value);
    void Turn(float Value);
    void LookUp(float Value);
};