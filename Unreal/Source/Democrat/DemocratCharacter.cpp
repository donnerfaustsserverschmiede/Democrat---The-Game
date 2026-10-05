#include "DemocratCharacter.h"
#include "Camera/CameraComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

ADemocratCharacter::ADemocratCharacter()
{
    PrimaryActorTick.bCanEverTick = false;

    CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
    CameraBoom->SetupAttachment(RootComponent);
    CameraBoom->TargetArmLength = 350.0f;
    CameraBoom->bUsePawnControlRotation = true;

    FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
    FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
    FollowCamera->bUsePawnControlRotation = false;

    GetCharacterMovement()->MaxWalkSpeed = 450.0f;
    GetCharacterMovement()->BrakingDecelerationWalking = 1800.0f;
}

void ADemocratCharacter::BeginPlay()
{
    Super::BeginPlay();
}

void ADemocratCharacter::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
    Super::SetupPlayerInputComponent(PlayerInputComponent);
    PlayerInputComponent->BindAxis(TEXT("MoveForward"), this, &ADemocratCharacter::MoveForward);
    PlayerInputComponent->BindAxis(TEXT("MoveRight"), this, &ADemocratCharacter::MoveRight);
    PlayerInputComponent->BindAxis(TEXT("Turn"), this, &ADemocratCharacter::Turn);
    PlayerInputComponent->BindAxis(TEXT("LookUp"), this, &ADemocratCharacter::LookUp);
}

void ADemocratCharacter::MoveForward(float Value)
{
    if (Controller && Value != 0.0f)
        AddMovementInput(GetActorForwardVector(), Value);
}

void ADemocratCharacter::MoveRight(float Value)
{
    if (Controller && Value != 0.0f)
        AddMovementInput(GetActorRightVector(), Value);
}

void ADemocratCharacter::Turn(float Value)
{
    AddControllerYawInput(Value);
}

void ADemocratCharacter::LookUp(float Value)
{
    AddControllerPitchInput(Value);
}