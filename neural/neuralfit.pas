(*
neuralfit
Copyright (C) 2024 Joao Paulo Schwarz Schuler

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*)
unit neuralfit;

{$include neuralnetwork.inc}

{$IFDEF FPC}
{$H+}
{$ENDIF}

interface

uses
  Classes, SysUtils, neuralnetwork, neuralvolume, neuralthread, neuraldatasets
  {$IFDEF OpenCL}, cl
  {$IFNDEF FPC}, neuralopencl {$ENDIF}
  {$ENDIF}
  {$IFNDEF FPC}, Windows {$ENDIF}
  ;

type
  TNeuralFitBase = class;

  // This is a base class for all optimizers
  TNeuralOptimizer = class(TMObject)
  private
    FNN: TNNet;
    FFit: TNeuralFitBase;
  public
    procedure ReSet(); virtual;
    procedure SetNN(pNN: TNNet; pFit: TNeuralFitBase);
    procedure Optimize(); virtual; abstract;
    procedure ForceDeltaLimists();
  end;

  // SGD optimization method
  TNeuralOptimizerSGD = class(TNeuralOptimizer)
  public
    procedure Reset(); override;
    procedure Optimize(); override;
  end;

  // Adam optimization method
  TNeuralOptimizerAdam = class(TNeuralOptimizer)
  protected
    FBeta1: TNeuralFloat;
    FBeta2: TNeuralFloat;
    FEpsilon: TNeuralFloat;
    FAdamInitialized: boolean;
  public
    constructor Create(
      Beta1: TNeuralFloat = 0.9;
      Beta2: TNeuralFloat = 0.98;
      Epsilon: TNeuralFloat = 1e-07); overload;

    // Memory Initializer for Adam optimizer
    function InitAdam(Beta1, Beta2, Epsilon: TNeuralFloat): TNNetLayer;

    procedure Optimize(); override;
    procedure ReSet(); override;
  end;

  TCustomLearningRateScheduleFn = function(Epoch: integer): single;
  TCustomLearningRateScheduleObjFn = function(Epoch: integer): single of object;

  {$IFNDEF HASTHREADS}
  TMultiThreadProcItem = TObject;
  {$ENDIF}

  TNeuralSaveBest = (SaveBestAccuracy, SaveBestLoss);

  /// This is a base class. Do not use it directly.
  TNeuralFitBase = class(TMObject)
    protected
      FBatchSize: integer;
      FMaxThreadNum, FDefaultThreadCount, FThreadNum: integer;
      FThreadNN: TNNetDataParallelism;
      FAvgWeights: TNNetDataParallelism;
      FAvgWeight: TNNet;
      FAvgWeightEpochCount: integer;
      FCurrentEpoch: integer;
      FCurrentStep: integer;
      FCurrentTrainingError: TNeuralFloat;
      FCustomLearningRateScheduleFn: TCustomLearningRateScheduleFn;
      FCustomLearningRateScheduleObjFn: TCustomLearningRateScheduleObjFn;
      FDataAugmentation: boolean;
      FFinishedThread: TNNetVolume;
      {$IFDEF HASTHREADS}FCritSec: TRTLCriticalSection;{$ENDIF}
      FNN: TNNet;
      FGlobalHit: integer;
      FGlobalMiss: integer;
      FGlobalTotal: integer;
      FGlobalTotalLoss: single;
      FGlobalErrorSum: single;
      FInertia: single;
      FStaircaseEpochs: integer;
      FStepSize: integer;
      FMaxEpochs: integer;
      FMultipleSamplesAtValidation: boolean;
      FVerbose: boolean;
      FLearningRateDecay: single;
      FInitialLearningRate: single;
      FCyclicalLearningRateLen: integer;
      FInitialEpoch: integer;
      FCurrentLearningRate: single;
      FL2Decay: TNeuralFloat;
      FLogEveryBatches: integer;
      FFileNameBase: string;
      FClipDelta: single;
      FClipNorm: single;
      FTargetAccuracy: single;
      FOnAfterStep, FOnAfterEpoch, FOnStart: TNotifyEvent;
      FRunning, FShouldQuit: boolean;
      FSaveBest: TNeuralSaveBest;
      FTrainingAccuracy, FValidationAccuracy, FTestAccuracy: TNeuralFloat;
      FValidationError, FValidationLoss: TNeuralFloat;
      FMinBackpropagationError: TNeuralFloat;
      FMinBackpropagationErrorProportion: TNeuralFloat;
      FLoadBestAdEnd: boolean;
      FTestBestAtEnd: boolean;
      {$IFDEF OpenCL}
      FPlatformId: cl_platform_id;
      FDeviceId: cl_device_id;
      {$ENDIF}
      FProcs: TNeuralThreadList;
      FOptimizer: TNeuralOptimizer;
      FOptimizerOwned: boolean;
      procedure CheckLearningRate(iEpochCount: integer);
      procedure Optimize();
      procedure SetOptimizer(pOptimizer: TNeuralOptimizer);
      procedure SetClipDelta(Value: TNeuralFloat);
      procedure SetClipNorm(Value: TNeuralFloat);
    public
      constructor Create(); override;
      destructor Destroy(); override;
      procedure WaitUntilFinished;
      {$IFDEF OpenCL}
      procedure DisableOpenCL();
      procedure EnableOpenCL(platform_id: cl_platform_id; device_id: cl_device_id);
      {$ENDIF}

      property AvgWeightEpochCount: integer read FAvgWeightEpochCount write FAvgWeightEpochCount;
      property AvgNN: TNNet read FAvgWeight;
      /// ClipDelta is a per neuron absolute max normalization.
      // This is useful for This is useful for making SGD numerically stable.
      property ClipDelta: single read FClipDelta write SetClipDelta;
      property ClipNorm: single read FClipNorm write SetClipNorm;
      property CurrentEpoch: integer read FCurrentEpoch;
      property CurrentStep: integer read FCurrentStep;
      property CurrentLearningRate: single read FCurrentLearningRate;
      property CurrentTrainingError: TNeuralFloat read FCurrentTrainingError;
      property CustomLearningRateScheduleFn: TCustomLearningRateScheduleFn read FCustomLearningRateScheduleFn write FCustomLearningRateScheduleFn;
      property CustomLearningRateScheduleObjFn: TCustomLearningRateScheduleObjFn read FCustomLearningRateScheduleObjFn write FCustomLearningRateScheduleObjFn;
      property CyclicalLearningRateLen: integer read FCyclicalLearningRateLen write FCyclicalLearningRateLen;
      property FileNameBase: string read FFileNameBase write FFileNameBase;
      property Inertia: single read FInertia write FInertia;
      property InitialEpoch: integer read FInitialEpoch write FInitialEpoch;
      property InitialLearningRate: single read FInitialLearningRate write FInitialLearningRate;
      property LearningRateDecay: single read FLearningRateDecay write FLearningRateDecay;
      property LoadBestAtEnd: boolean read FLoadBestAdEnd write FLoadBestAdEnd;
      property LogEveryBatches: integer read FLogEveryBatches write FLogEveryBatches;
      property L2Decay: single read FL2Decay write FL2Decay;
      property MaxThreadNum: integer read FMaxThreadNum write FMaxThreadNum;
      property MinBackpropagationError: TNeuralFloat read FMinBackpropagationError write FMinBackpropagationError;
      property MinBackpropagationErrorProportion: TNeuralFloat read FMinBackpropagationErrorProportion write FMinBackpropagationErrorProportion;
      property Momentum: single read FInertia write FInertia;
      property MultipleSamplesAtValidation: boolean read FMultipleSamplesAtValidation write FMultipleSamplesAtValidation;
      property NN: TNNet read FNN;
      property OnAfterStep: TNotifyEvent read FOnAfterStep write FOnAfterStep;
      property OnAfterEpoch: TNotifyEvent read FOnAfterEpoch write FOnAfterEpoch;
      property OnStart: TNotifyEvent read FOnStart write FOnStart;
      property Optimizer: TNeuralOptimizer read FOptimizer write SetOptimizer;
      property SaveBest: TNeuralSaveBest read FSaveBest write FSaveBest;
      property StaircaseEpochs: integer read FStaircaseEpochs write FStaircaseEpochs;
      property TargetAccuracy: single read FTargetAccuracy write FTargetAccuracy;
      property TestBestAtEnd: boolean read FTestBestAtEnd write FTestBestAtEnd;
      property ValidationAccuracy: TNeuralFloat read FValidationAccuracy;
      property ValidationError: TNeuralFloat read FValidationError;
      property ValidationLoss: TNeuralFloat read FValidationLoss;
      property Verbose: boolean read FVerbose write FVerbose;
      property TestAccuracy: TNeuralFloat read FTestAccuracy;
      property ThreadNN: TNNetDataParallelism read FThreadNN;
      property TrainingAccuracy: TNeuralFloat read FTrainingAccuracy;
      property Running: boolean read FRunning;
      property ShouldQuit: boolean read FShouldQuit write FShouldQuit;
  end;

  { TNeuralFitWithImageBase }

  TNeuralFitWithImageBase = class(TNeuralFitBase)
    protected
      FMaxCropSize: integer;
      FHasImgCrop: boolean;
      FHasMakeGray: boolean;
      FHasFlipX: boolean;
      FHasFlipY: boolean;
      FHasResizing: boolean;
      FColorEncoding: integer;
      FChannelShiftRate: TNeuralFloat;
    public
      constructor Create(); override;
      destructor Destroy(); override;
      procedure ClassifyImage(pNN: TNNet; pImgInput, pOutput: TNNetVolume);
      procedure ClassifyImageFromFile(pNN: TNNet; pFilename: string; pOutput: TNNetVolume); overload;
      function ClassifyImageFromFile(pNN: TNNet; pFilename: string):integer; overload;
      procedure EnableDefaultImageTreatment(); virtual;

      // ChannelShiftRate: 0 means no augmentation. 0.1 means 10% of maximum change per channel.
      property ChannelShiftRate: TNeuralFloat read FChannelShiftRate write FChannelShiftRate;
      property HasImgCrop: boolean read FHasImgCrop write FHasImgCrop;
      property HasMakeGray: boolean read FHasMakeGray write FHasMakeGray;
      property HasFlipX: boolean read FHasFlipX write FHasFlipX;
      property HasFlipY: boolean read FHasFlipY write FHasFlipY;
      property HasResizing: boolean read FHasResizing write FHasResizing;
      property MaxCropSize: integer read FMaxCropSize write FMaxCropSize;
  end;

  TNNetDataAugmentationFn = procedure(pInput: TNNetVolume; ThreadId: integer) of object;
  TNNetLossFn = function(ExpectedOutput, FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat of object;
  TNNetInferHitFn = function(A, B: TNNetVolume; ThreadId: integer): boolean;
  TNNetGetPairFn = function(Idx: integer; ThreadId: integer): TNNetVolumePair of object;
  TNNetGet2VolumesProc = procedure(Idx: integer; ThreadId: integer; pInput, pOutput: TNNetVolume) of object;

  /// Fitting algorithm with data (pairs) loading
  TNeuralDataLoadingFit = class(TNeuralFitWithImageBase)
  private
    protected
      FDataAugmentationFn: TNNetDataAugmentationFn;
      FInferHitFn: TNNetInferHitFn;
      FLossFn: TNNetLossFn;
      FTestSize: integer;

      FLocalTestPair: TNNetGetPairFn;
      FLocalTestProc: TNNetGet2VolumesProc;
      FGetTrainingPair, FGetValidationPair, FGetTestPair: TNNetGetPairFn;
      FGetTrainingProc, FGetValidationProc, FGetTestProc: TNNetGet2VolumesProc;
      function DefaultLossFn(ExpectedOutput, FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
      function MultiClassLossFn(ExpectedOutput, FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
      function DefaultLossInFirstPixelFn(ExpectedOutput, FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
      function DefaultLossInLastPixelFn(ExpectedOutput, FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
    public
      constructor Create(); override;
      procedure FitLoading(pNN: TNNet;
        TrainingCnt, ValidationCnt, TestCnt, pBatchSize, Epochs: integer;
        pGetTrainingPair, pGetValidationPair, pGetTestPair: TNNetGetPairFn); overload;
      procedure FitLoading(pNN: TNNet;
        TrainingCnt, ValidationCnt, TestCnt, pBatchSize, Epochs: integer;
        pGetTrainingProc, pGetValidationProc, pGetTestProc: TNNetGet2VolumesProc); overload;

      procedure EnableMonopolarHitComparison();
      procedure EnableBipolarHitComparison();
      procedure EnableBipolar99HitComparison();
      procedure EnableClassComparison();
      procedure EnableMultiClassComparison();
      procedure EnableClassComparisonInFirstPixel();
      procedure EnableClassComparisonInLastPixel();
      procedure EnableDefaultImageTreatment(); override;
      procedure EnableDefaultLoss;
      procedure EnableMultiClassLoss;
      procedure EnableDefaultLossInFirstPixel();
      procedure EnableDefaultLossInLastPixel();

      // On most cases, you should never call the following methods directly
      procedure RunNNThread(index, threadnum: integer);
      procedure TestNNThread(index, threadnum: integer);

      procedure AllocateMemory(pNN: TNNet;
        pBatchSize: integer;
        pGetTrainingPair, pGetValidationPair, pGetTestPair: TNNetGetPairFn); overload;
      procedure AllocateMemory(pNN: TNNet;
        pBatchSize: integer;
        pGetTrainingProc, pGetValidationProc, pGetTestProc: TNNetGet2VolumesProc); overload;
      procedure FreeMemory();
      procedure RunTrainingBatch();
      procedure RunValidationBatch(ValidationSize: integer);
      procedure RunTestBatch(TestSize: integer);

      property DataAugmentationFn: TNNetDataAugmentationFn read FDataAugmentationFn write FDataAugmentationFn;
      property InferHitFn: TNNetInferHitFn read FInferHitFn write FInferHitFn;
      property LossFn: TNNetLossFn read FLossFn write FLossFn;
  end;

  /// Generic Neural Network Fitting Algorithm
  TNeuralFit = class(TNeuralDataLoadingFit)
    protected
      FTrainingVolumes, FValidationVolumes, FTestVolumes: TNNetVolumePairList;
      FWorkingVolumes: TNNetVolumePairList;

      function FitTrainingPair(Idx: integer; ThreadId: integer): TNNetVolumePair;
      function FitValidationPair(Idx: integer; ThreadId: integer): TNNetVolumePair;
      function FitTestPair(Idx: integer; ThreadId: integer): TNNetVolumePair;
    public
      constructor Create(); override;
      destructor Destroy(); override;

      procedure Fit(pNN: TNNet;
        pTrainingVolumes, pValidationVolumes, pTestVolumes: TNNetVolumePairList;
        pBatchSize, Epochs: integer);
  end;

  {$IFDEF FPC}
  { TNeuralImageLoadingFit }
  TNeuralImageLoadingFit = class(TNeuralDataLoadingFit)
    protected
      FSizeX, FSizeY: integer;
      FTrainingFileNames, FValidationFileNames, FTestFileNames: TFileNameList;
      FTrainingVolumeCache: TNNetVolumeList;
      FTrainingVolumeCacheEnabled: boolean;
      FTrainingVolumeCacheSize: integer;
      FTrainingVolumeCachePct: integer;
      FTrainingSampleProcessedCnt: TNNetVolume;

      procedure GetTrainingProc(Idx: integer; ThreadId: integer; pInput, pOutput: TNNetVolume);
      procedure GetValidationProc(Idx: integer; ThreadId: integer; pInput, pOutput: TNNetVolume);
      procedure GetTestProc(Idx: integer; ThreadId: integer; pInput, pOutput: TNNetVolume);
    public
      constructor Create(); override;
      destructor Destroy(); override;

      procedure FitLoading(pNN: TNNet;
        pSizeX, pSizeY: integer;
        pTrainingFileNames, pValidationFileNames, pTestFileNames: TFileNameList;
        pBatchSize, Epochs: integer); overload;

      property SizeX:integer read FSizeX;
      property SizeY:integer read FSizeX;
      property TrainingVolumeCacheEnabled: boolean read FTrainingVolumeCacheEnabled write FTrainingVolumeCacheEnabled;
      property TrainingVolumeCacheSize: integer read FTrainingVolumeCacheSize write FTrainingVolumeCacheSize;
      property TrainingVolumeCachePct: integer read FTrainingVolumeCachePct write FTrainingVolumeCachePct;
  end;
  {$ENDIF}

  /// Image Classification Fitting Algorithm
  TNeuralImageFit = class(TNeuralFitWithImageBase)
    protected
      FWorkingVolumes: TNNetVolumeList;
      FNumClasses: integer;
      FImgVolumes, FImgValidationVolumes, FImgTestVolumes: TNNetVolumeList;
      FIsSoftmax: boolean;
      FTrainingSampleProcessedCnt: TNNetVolume;
    public
      constructor Create(); override;
      destructor Destroy(); override;

      procedure Fit(pNN: TNNet;
        pImgVolumes, pImgValidationVolumes, pImgTestVolumes: TNNetVolumeList;
        pNumClasses, pBatchSize, Epochs: integer);
      procedure RunNNThread(index, threadnum: integer);
      procedure TestNNThread(index, threadnum: integer);
  end;

  function MonopolarCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
  function BipolarCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
  function BipolarCompare99(A, B: TNNetVolume; ThreadId: integer): boolean;
  function ClassCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
  function MultiClassCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
  function ClassCompareOnFirstPixel(A, B: TNNetVolume; ThreadId: integer): boolean;
  function ClassCompareOnLastPixel(A, B: TNNetVolume; ThreadId: integer): boolean;

implementation
uses
  math;

function MonopolarCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
var
  Pos: integer;
  ACount, BCount: integer;
begin
  ACount := A.Size;
  BCount := B.Size;
  Result := (ACount>0) and (ACount = BCount);
  Pos := 0;
  while Result and (Pos < ACount) do
  begin
    Result := Result and (
      ( (A.FData[Pos]>0.5) and (B.FData[Pos]>0.5) ) or
      ( (A.FData[Pos]<0.5) and (B.FData[Pos]<0.5) )
    );
    Inc(Pos);
  end;
end;

function BipolarCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
var
  Pos: integer;
  ACount, BCount: integer;
begin
  ACount := A.Size;
  BCount := B.Size;
  Result := (ACount>0) and (ACount = BCount);
  Pos := 0;
  while Result and (Pos < ACount) do
  begin
    Result := Result and (
      ( (A.FData[Pos]>0) and (B.FData[Pos]>0) ) or
      ( (A.FData[Pos]<0) and (B.FData[Pos]<0) )
    );
    Inc(Pos);
  end;
end;

function BipolarCompare99(A, B: TNNetVolume; ThreadId: integer): boolean;
var
  Pos, Hits: integer;
  ACount: integer;
begin
  ACount := Min(A.Size, B.Size);
  Pos := 0;
  Hits := 0;
  while (Pos < ACount) do
  begin
    if (
      ( (A.FData[Pos]>0) and (B.FData[Pos]>0) ) or
      ( (A.FData[Pos]<0) and (B.FData[Pos]<0) )
    ) then Inc(Hits);
    Inc(Pos);
  end;
  Result := (Hits > Round(ACount*0.99));
end;

function ClassCompare(A, B: TNNetVolume; ThreadId: integer): boolean;
begin
  Result := (A.GetClass() = B.GetClass());
end;

function ClassCompareOnFirstPixel(A, B: TNNetVolume; ThreadId: integer
  ): boolean;
begin
  Result := (A.GetClassOnPixel(0, 0) = B.GetClassOnPixel(0, 0));
end;

function ClassCompareOnLastPixel(A, B: TNNetVolume; ThreadId: integer): boolean;
// var
//  AClass, BClass: integer;
begin
//  AClass := A.GetClassOnPixel(A.SizeX-1, A.SizeY-1);
//  BClass := B.GetClassOnPixel(B.SizeX-1, B.SizeY-1);
//  if (Random(1000)=0) then WriteLn(AClass,'-->',BClass);
  Result := (A.GetClassOnPixel(A.SizeX-1, A.SizeY-1) = B.GetClassOnPixel(B.SizeX-1, B.SizeY-1));
end;

function MultiClassCompare(A, B: TNNetVolume; ThreadId: integer
  ): boolean;
var
  I, StartPointPos: integer;
  MaxX, MaxY, MaxD: integer;
  LocalPos, LocalClassA, LocalClassB: integer;
  CountX, CountY, CountD: integer;
  MaxValueA, MaxValueB: TNeuralFloat;
begin
  Result := True;
  if Not(A.SameSize(B)) then
  begin
    Result := false;
    exit;
  end;
  // TODO: This portion of code can be optimized
  MaxX := A.SizeX - 1;
  MaxY := A.SizeY - 1;
  MaxD := A.Depth - 1;

  if MaxD > 0 then
  begin
    for CountX := 0 to MaxX do
    begin
      if Result then for CountY := 0 to MaxY do
      begin
        StartPointPos := A.GetRawPos(CountX, CountY);
        // Get the A Class
        I := StartPointPos;
        MaxValueA := A.FData[I];
        LocalPos := 0;
        LocalClassA := 0;
        if Result then for CountD := 1 to MaxD do
        begin
          Inc(I);
          Inc(LocalPos);
          if A.FData[I] > MaxValueA then
          begin
            MaxValueA := A.FData[I];
            LocalClassA := LocalPos;
          end;
        end;
        // Get the B Class
        I := StartPointPos;
        MaxValueB := B.FData[I];
        LocalPos := 0;
        LocalClassB := 0;
        if Result then for CountD := 1 to MaxD do
        begin
          Inc(I);
          Inc(LocalPos);
          if B.FData[I] > MaxValueB then
          begin
            MaxValueB := B.FData[I];
            LocalClassB := LocalPos;
          end;
        end;
        if (MaxValueA>0) and (MaxValueB>0) and (LocalClassA <> LocalClassB) then
        begin
          Result := False;
          Break;
        end;
      end;
    end;
  end;
end;


{$IFDEF FPC}
{ TNeuralImageLoadingFit }
procedure TNeuralImageLoadingFit.GetTrainingProc(Idx: integer;
  ThreadId: integer; pInput, pOutput: TNNetVolume);
var
  AuxVolume: TNNetVolume;
  CacheId: integer;
  LocalCacheVolume: TNNetVolume;
  ImageId: integer;
  MaxLen: integer;
begin
  if FTrainingVolumeCacheEnabled then
  begin
    CacheId := Random(FTrainingVolumeCacheSize);
    LocalCacheVolume := FTrainingVolumeCache[CacheId];
    if ((LocalCacheVolume.Tag = -1) or (Random(1000)>FTrainingVolumeCachePct*10)) then
    begin
      AuxVolume := TNNetVolume.Create();
      ImageId := TNeuralThreadList.GetRandomNumberOnWorkingRange(ThreadId, FThreadNum, FTrainingFileNames.Count, MaxLen);
      ImageId := FTrainingSampleProcessedCnt.GetSmallestIdxInRange(ImageId, Min(MaxLen,100));
      FTrainingFileNames.GetImageVolumePairFromId(ImageId, AuxVolume, pOutput, false);
      pInput.CopyResizing(AuxVolume, FSizeX, FSizeY);
      LocalCacheVolume.Copy(pInput);
      LocalCacheVolume.Tag := AuxVolume.Tag;
      pInput.Tag := AuxVolume.Tag;
      AuxVolume.Free;
    end
    else
    begin
      pInput.Copy(LocalCacheVolume);
      pOutput.ReSize(FTrainingFileNames.ClassCount);
      pOutput.SetClassForSoftMax(LocalCacheVolume.Tag);
      pInput.Tag := LocalCacheVolume.Tag;
      pOutput.Tag := LocalCacheVolume.Tag;
    end;
  end
  else
  begin
    AuxVolume := TNNetVolume.Create();
    ImageId := TNeuralThreadList.GetRandomNumberOnWorkingRange(ThreadId, FThreadNum, FTrainingFileNames.Count, MaxLen);
    ImageId := FTrainingSampleProcessedCnt.GetSmallestIdxInRange(ImageId, Min(MaxLen,100));
    FTrainingFileNames.GetImageVolumePairFromId(ImageId, AuxVolume, pOutput, false);
    pInput.CopyResizing(AuxVolume, FSizeX, FSizeY);
    pInput.Tag := AuxVolume.Tag;
    AuxVolume.Free;
  end;
end;

procedure TNeuralImageLoadingFit.GetValidationProc(Idx: integer;
  ThreadId: integer; pInput, pOutput: TNNetVolume);
var
  AuxVolume: TNNetVolume;
begin
  AuxVolume := TNNetVolume.Create();
  FValidationFileNames.GetImageVolumePairFromId(Idx, AuxVolume, pOutput, false);
  pInput.CopyResizing(AuxVolume, FSizeX, FSizeY);
  pInput.Tag := AuxVolume.Tag;
  AuxVolume.Free;
end;

procedure TNeuralImageLoadingFit.GetTestProc(Idx: integer; ThreadId: integer;
  pInput, pOutput: TNNetVolume);
var
  AuxVolume: TNNetVolume;
begin
  AuxVolume := TNNetVolume.Create();
  FTestFileNames.GetImageVolumePairFromId(Idx, AuxVolume, pOutput, false);
  pInput.CopyResizing(AuxVolume, FSizeX, FSizeY);
  pInput.Tag := AuxVolume.Tag;
  AuxVolume.Free;
end;

constructor TNeuralImageLoadingFit.Create();
begin
  inherited Create();
  FTrainingVolumeCacheSize := 1000;
  FTrainingVolumeCachePct := 50;
  FTrainingVolumeCacheEnabled := false;
  EnableDefaultImageTreatment();
  FTrainingSampleProcessedCnt := TNNetVolume.Create();
end;

destructor TNeuralImageLoadingFit.Destroy();
begin
  FTrainingSampleProcessedCnt.Free;
  inherited Destroy();
end;

procedure TNeuralImageLoadingFit.FitLoading(pNN: TNNet; pSizeX,
  pSizeY: integer; pTrainingFileNames, pValidationFileNames,
  pTestFileNames: TFileNameList; pBatchSize, Epochs: integer);
begin
  FSizeX := pSizeX;
  FSizeY := pSizeY;
  FTrainingFileNames   := pTrainingFileNames;
  FValidationFileNames := pValidationFileNames;
  FTestFileNames       := pTestFileNames;
  FTrainingVolumeCache := TNNetVolumeList.Create;
  FTrainingSampleProcessedCnt.Resize(FTrainingFileNames.Count);
  if Not(FTrainingVolumeCacheEnabled) then FTrainingVolumeCacheSize := 1;
  FTrainingVolumeCache.AddVolumes(FTrainingVolumeCacheSize, FSizeX, FSizeY, 3);
  FTrainingVolumeCache.FillTag({TagId}0, {TagValue}-1);
  FitLoading(pNN,
    FTrainingFileNames.Count, FValidationFileNames.Count, FTestFileNames.Count,
    pBatchSize, Epochs, @Self.GetTrainingProc, @Self.GetValidationProc, @Self.GetTestProc
  );
  FTrainingVolumeCache.Free;
end;
{$ENDIF}

procedure TNeuralFitBase.Optimize();
begin
  if FOptimizer = nil then
  begin
    FOptimizer := TNeuralOptimizerSGD.Create();
    FOptimizerOwned := true;
  end;
  FOptimizer.SetNN(FNN, Self);
  FOptimizer.Optimize();
  //Write(FNN.ForceMaxAbsoluteWeight(2):3:2,' ');
  if FL2Decay > 0.0 then FNN.ComputeL2Decay();
end;

constructor TNeuralFitWithImageBase.Create();
begin
  inherited Create();
  FMaxCropSize := 0;
  FHasImgCrop := false;
  FHasFlipX := false;
  FHasFlipY := false;
  FHasMakeGray := false;
  FColorEncoding := 0;
  FMultipleSamplesAtValidation := false;
  FChannelShiftRate := 0;
end;

destructor TNeuralFitWithImageBase.Destroy();
begin
  inherited Destroy();
end;

{ TNeuralDataLoadingFit }

function TNeuralDataLoadingFit.DefaultLossFn(ExpectedOutput,
  FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
var
  ClassId: integer;
  OutputValue: TNeuralFloat;
begin
  ClassId := ExpectedOutput.Tag;
  OutputValue := FoundOutput.FData[ ClassId ];

  {$IFDEF Debug}
  //if ClassId <> ExpectedOutput.GetClass() then
  //begin
  //  FErrorProc(
  //    'Error - classes do not match at TNeuralDataLoadingFit.DefaultLossFn:' +
  //    IntToStr(ClassId)+','+IntToStr(ExpectedOutput.GetClass())
  //  );
  //end;
  {$ENDIF}

  if (OutputValue > 0) then
  begin
    result := -Ln(OutputValue);
  end
  else
  begin
    {$IFDEF Debug}
    //FErrorProc('Error - invalid output value at loss function:' + FloatToStrF(OutputValue,ffFixed,6,4));
    {$ENDIF}
    result := 100;
  end;
end;

function TNeuralDataLoadingFit.MultiClassLossFn(ExpectedOutput,
  FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
var
  I, StartPointPos: integer;
  MaxX, MaxY, MaxD: integer;
  CountX, CountY, CountD: integer;
  LocalValue, MaxValue: TNeuralFloat;
  ClassesCnt: TNeuralFloat;
  LossSum: TNeuralFloat;
  MaxPos: integer;
begin
  if Not(ExpectedOutput.SameSize(FoundOutput)) then
  begin
    Result := 100;
    exit;
  end;
  ClassesCnt := 0;
  LossSum := 0;
  // TODO: This portion of code can be optimized
  MaxX := ExpectedOutput.SizeX - 1;
  MaxY := ExpectedOutput.SizeY - 1;
  MaxD := ExpectedOutput.Depth - 1;

  if MaxD > 0 then
  begin
    for CountX := 0 to MaxX do
    begin
      for CountY := 0 to MaxY do
      begin
        StartPointPos := ExpectedOutput.GetRawPos(CountX, CountY);
        // Get the A Class
        I := StartPointPos;
        MaxValue := ExpectedOutput.FData[I];
        MaxPos := 0;
        for CountD := 1 to MaxD do
        begin
          Inc(I);
          if ExpectedOutput.FData[I] > MaxValue then
          begin
            MaxValue := ExpectedOutput.FData[I];
            MaxPos := I;
          end;
          if MaxValue >= 1 then break;
        end;
        If MaxValue > 0 then
        begin
          ClassesCnt := ClassesCnt + 1;
          LocalValue := FoundOutput.FData[MaxPos];
          if LocalValue>0
          then LossSum := LossSum + -Ln(LocalValue)
          else LossSum := LossSum + 100;
        end;
      end;
    end;
  end;
  if ClassesCnt > 0
  then Result := LossSum/ClassesCnt
  else Result := 0;
end;

function TNeuralDataLoadingFit.DefaultLossInFirstPixelFn(ExpectedOutput,
  FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
var
  ClassId: integer;
  OutputValue: TNeuralFloat;
begin
  ClassId := ExpectedOutput.Tag;
  OutputValue := FoundOutput[0, 0, ClassId];

  {$IFDEF Debug}
  (*
  if ClassId <> ExpectedOutput.GetClass() then
  begin
    FErrorProc(
      'Error - classes do not match at TNeuralDataLoadingFit.DefaultLossFn:' +
      IntToStr(ClassId)+','+IntToStr(ExpectedOutput.GetClass())
    );
  end;
  *)
  {$ENDIF}

  if (OutputValue > 0) then
  begin
    result := -Ln(OutputValue);
  end
  else
  begin
    {$IFDEF Debug}
    //FErrorProc('Error - invalid output value at loss function:' + FloatToStrF(OutputValue,ffFixed,6,4));
    {$ENDIF}
    result := 100;
  end;
end;

function TNeuralDataLoadingFit.DefaultLossInLastPixelFn(ExpectedOutput,
  FoundOutput: TNNetVolume; ThreadId: integer): TNeuralFloat;
var
  ClassId: integer;
  OutputValue: TNeuralFloat;
begin
  ClassId := ExpectedOutput.GetClassOnPixel(ExpectedOutput.SizeX - 1, ExpectedOutput.SizeY - 1);
  OutputValue := FoundOutput[FoundOutput.SizeX - 1, FoundOutput.SizeY - 1, ClassId];
  if (OutputValue > 0) then
  begin
    result := -Ln(OutputValue);
  end
  else
  begin
    {$IFDEF Debug}
    //FErrorProc('Error - invalid output value at loss function:' + FloatToStrF(OutputValue,ffFixed,6,4));
    {$ENDIF}
    result := 100;
  end;
end;

constructor TNeuralDataLoadingFit.Create();
begin
  inherited Create;
  FGetTrainingPair := nil;
  FGetValidationPair := nil;
  FGetTestPair := nil;
  FLossFn := nil;
  FTestSize := 0;
end;

procedure TNeuralDataLoadingFit.FitLoading(pNN: TNNet; TrainingCnt,
  ValidationCnt, TestCnt, pBatchSize, Epochs: integer;
  pGetTrainingPair, pGetValidationPair,
  pGetTestPair: TNNetGetPairFn);
var
  globalStartTime: double;
  TestError, TestLoss, TestRate: TNeuralFloat;
  procedure RunTest();
  begin
          RunTestBatch(TestCnt);
          if FGlobalTotal > 0 then
          begin
            TestRate  := FGlobalHit / FGlobalTotal;
            TestLoss  := FGlobalTotalLoss / FGlobalTotal;
            TestError := FGlobalErrorSum / FGlobalTotal;
            FTestAccuracy := TestRate;
          end;
          if (FGlobalTotal > 0) and (FVerbose) then
          begin
            FMessageProc(
              'Epochs: ' + IntToStr(FCurrentEpoch) +
              ' Examples seen:' + IntToStr(FCurrentEpoch * TrainingCnt) +
              ' Test Accuracy: ' + FloatToStrF(TestRate,ffFixed,6,4) +
              ' Test Error: ' + FloatToStrF(TestError,ffFixed,6,4) +
              ' Test Loss: ' + FloatToStrF(TestLoss,ffFixed,6,4) +
              ' Total time: ' + FloatToStrF(((Now() - globalStartTime)) * 24 * 60,ffFixed,6,2) +
              'min'
            );
          end;
  end;
var
  I: integer;
  startTime, totalTimeSeconds: double;
  fileName, FileNameCSV: string;
  CurrentError, CurrentLoss: TNeuralFloat;
  ValidationRate: TNeuralFloat;
  CSVFile: TextFile;
  CurrentAccuracy, AccuracyWithInertia: TNeuralFloat;
  ValidationRecord: TNeuralFloat;
begin
  AllocateMemory(pNN, pBatchSize, pGetTrainingPair,
    pGetValidationPair, pGetTestPair);
  FMaxEpochs := Epochs;
  AccuracyWithInertia := 0;
  CurrentError := 0;
  CurrentLoss := 0;
  ValidationRate := 0;
  FValidationLoss := 0;
  FValidationError := 0;
  TestRate := 0;
  TestLoss := 0;
  TestError := 0;
  if FSaveBest = SaveBestAccuracy
  then ValidationRecord := 0
  else ValidationRecord := 100;
  totalTimeSeconds := 0;

  FMessageProc('File name is: ' + FFileNameBase);
  FileNameCSV := FFileNameBase + '.csv';
  FileName := FFileNameBase + '.nn';

  AssignFile(CSVFile, FileNameCSV);
  ReWrite(CSVFile);
  WriteLn(CSVFile, 'epoch,training accuracy,training loss,training error,validation accuracy,validation loss,validation error,learning rate,time,test accuracy,test loss,test error');

  if FVerbose then
  begin
    MessageProc(
      'Learning rate:' + FloatToStrF(FCurrentLearningRate,ffFixed,8,6) +
      ' Clip norm:' + FloatToStrF(FClipNorm,ffFixed,8,6) +
      ' Clip delta:' + FloatToStrF(FClipDelta,ffFixed,8,6) +
      ' L2 decay:' + FloatToStrF(FL2Decay,ffFixed,8,6) +
      ' Inertia:' + FloatToStrF(FInertia,ffFixed,8,6) +
      ' Batch size:' + IntToStr(FBatchSize) +
      ' Step size:' + IntToStr(FStepSize) +
      ' Staircase ephocs:' + IntToStr(FStaircaseEpochs)
    );
    if TrainingCnt > 0 then MessageProc('Training volumes: '+IntToStr(TrainingCnt));
    if ValidationCnt > 0 then MessageProc('Validation volumes: '+IntToStr(ValidationCnt));
    if TestCnt > 0 then MessageProc('Test volumes: '+IntToStr(TestCnt));
  end;

  if FVerbose then
  begin
    MessageProc('Computing...');
  end;
  if Assigned(FOnStart) then FOnStart(Self);
  globalStartTime := Now();
  while ( (FMaxEpochs > FCurrentEpoch) and Not(FShouldQuit) ) do
  begin
    FGlobalErrorSum := 0;
    startTime := Now();
    CheckLearningRate(FCurrentEpoch);
    for I := 1 to (TrainingCnt div FStepSize) {$IFDEF MakeQuick}div 10{$ENDIF} do
    begin
      if FShouldQuit then break;
      RunTrainingBatch();

      FGlobalTotal := (FGlobalHit + FGlobalMiss);
      if (FGlobalTotal > 0) then
      begin
        CurrentError := FGlobalErrorSum / FGlobalTotal;
        FCurrentTrainingError := CurrentError;
        CurrentLoss  := FGlobalTotalLoss / FGlobalTotal;
        CurrentAccuracy := (FGlobalHit*100) div FGlobalTotal;
        if (FCurrentEpoch = FInitialEpoch) and (I = 1) then
        begin
          AccuracyWithInertia := CurrentAccuracy;
        end else if (FStepSize < 1280) then
        begin
          AccuracyWithInertia := AccuracyWithInertia*0.99 + CurrentAccuracy*0.01;
        end
        else if (FStepSize < 5120) then
        begin
          AccuracyWithInertia := AccuracyWithInertia*0.9 + CurrentAccuracy*0.1;
        end
        else
        begin
          AccuracyWithInertia := CurrentAccuracy;
        end;
        FTrainingAccuracy := AccuracyWithInertia/100;
      end;

      if ( (FGlobalTotal > 0) and (I mod FLogEveryBatches = 0) ) then
      begin
        totalTimeSeconds := (Now() - startTime) * 24 * 60 * 60;
        if FVerbose then MessageProc
        (
          IntToStr((FGlobalHit + FGlobalMiss)*I + FCurrentEpoch*TrainingCnt) +
          ' Examples seen. Accuracy: ' + FloatToStrF(FTrainingAccuracy,ffFixed,6,4) +
          ' Error: ' + FloatToStrF(CurrentError,ffFixed,10,5) +
          ' Loss: ' + FloatToStrF(CurrentLoss,ffFixed,7,5) +
          ' Threads: ' + IntToStr(FThreadNum) +
          ' Forward time: ' + FloatToStrF(FNN.ForwardTime * 24 * 60 * 60,ffFixed,6,2)+'s' +
          ' Backward time: ' + FloatToStrF(FNN.BackwardTime * 24 * 60 * 60,ffFixed,6,2)+'s'+
          ' Step time: ' + FloatToStrF(totalTimeSeconds,ffFixed,6,2) + 's'
        );

        startTime := Now();
      end;
      if Assigned(FOnAfterStep) then FOnAfterStep(Self);
      Inc(FCurrentStep);
    end;

    Inc(FCurrentEpoch);

    if not Assigned(FAvgWeights) then
    begin
      FAvgWeight.CopyWeights(FNN);
      if FAvgWeightEpochCount > 1
      then FAvgWeights := TNNetDataParallelism.Create(FNN, FAvgWeightEpochCount)
      else FAvgWeights := TNNetDataParallelism.Create(FNN, 1)
    end;

    if Not(FShouldQuit) and (Assigned(FGetValidationPair) or Assigned(FGetValidationProc)) then
    begin
      if FAvgWeightEpochCount > 1 then
      begin
        FAvgWeights.ReplaceAtIdxAndUpdateWeightAvg(FCurrentEpoch mod FAvgWeightEpochCount, FNN, FAvgWeight);
      end
      else
      begin
        FAvgWeight.CopyWeights(FNN);
      end;

      if (ValidationCnt > 0) and Not(FShouldQuit) then
      begin
        RunValidationBatch(ValidationCnt);

        if FGlobalTotal > 0 then
        begin
          ValidationRate  := FGlobalHit / FGlobalTotal;
          FValidationLoss  := FGlobalTotalLoss / FGlobalTotal;
          FValidationError := FGlobalErrorSum / FGlobalTotal;
          FValidationAccuracy := ValidationRate;
        end;

        if (FSaveBest = SaveBestAccuracy) then
        begin
          if (ValidationRate > ValidationRecord) then
          begin
            ValidationRecord := ValidationRate;
            FMessageProc('VALIDATION RECORD! Saving NN at '+fileName);
            FAvgWeight.SaveToFile(fileName);
          end;
        end;

        if (FSaveBest = SaveBestLoss) then
        begin
          if (FValidationLoss < ValidationRecord) then
          begin
            ValidationRecord := FValidationLoss;
            FMessageProc('VALIDATION RECORD! Saving NN at '+fileName);
            FAvgWeight.SaveToFile(fileName);
          end;
        end;

        if (FGlobalTotal > 0) and (FVerbose) then
        begin
          FMessageProc(
            'Epochs: ' + IntToStr(FCurrentEpoch) +
            ' Examples seen:' + IntToStr(FCurrentEpoch * TrainingCnt) +
            ' Validation Accuracy: ' + FloatToStrF(ValidationRate,ffFixed,6,4) +
            ' Validation Error: ' + FloatToStrF(FValidationError,ffFixed,6,4) +
            ' Validation Loss: ' + FloatToStrF(FValidationLoss,ffFixed,6,4) +
            ' Total time: ' + FloatToStrF(((Now() - globalStartTime)) * 24 * 60,ffFixed,6,2) +
            'min'
          );
        end;

        if (ValidationRate >= FTargetAccuracy) then
        begin
          FMessageProc('ValidationRate passed TargetAccuracy.');
          FShouldQuit := true;
          break;
        end;
      end;// Assigned(pGetValidationPair)

      if (FCurrentEpoch mod FThreadNN.Count = 0) and (FVerbose) then
      begin
        FThreadNN[0].DebugWeights();
      end;

      if (TestCnt > 0) and Not(FShouldQuit) and (Assigned(FGetTestPair) or Assigned(FGetTestProc)) then
      begin
        if ( (FCurrentEpoch mod 10 = 0) and (FCurrentEpoch > 0) ) then
        begin
          RunTest();
        end;
        if (TestRate >= FTargetAccuracy) then
        begin
          FMessageProc('TestRate passed TargetAccuracy.');
          FShouldQuit := true;
          break;
        end;
      end;
    end
    else
    begin
      FMessageProc('Skipping Validation. Saving NN at '+fileName);
      FAvgWeight.SaveToFile(fileName);
    end;
    if ( (FCurrentEpoch mod 10 = 0) and (FCurrentEpoch > 0) ) then
    begin
        WriteLn
        (
          CSVFile,
          FCurrentEpoch,',',
          (AccuracyWithInertia/100):6:4,',',
          CurrentLoss:6:4,',',
          CurrentError:6:4,',',
          ValidationRate:6:4,',',
          FValidationLoss:6:4,',',
          FValidationError:6:4,',',
          FCurrentLearningRate:9:7,',',
          Round( (Now() - globalStartTime) * 24 * 60 * 60),',',
          TestRate:6:4,',',
          TestLoss:6:4,',',
          TestError:6:4
        );
    end
    else
    begin
        WriteLn
        (
          CSVFile,
          FCurrentEpoch,',',
          (AccuracyWithInertia/100):6:4,',',
          CurrentLoss:6:4,',',
          CurrentError:6:4,',',
          ValidationRate:6:4,',',
          FValidationLoss:6:4,',',
          FValidationError:6:4,',',
          FCurrentLearningRate:9:7,',',
          Round( (Now() - globalStartTime) * 24 * 60 * 60),',,,'
        );
    end;

    CloseFile(CSVFile);
    AssignFile(CSVFile, FileNameCSV);
    Append(CSVFile);

    MessageProc(
      'Epoch time: ' + FloatToStrF( totalTimeSeconds*(TrainingCnt/(FStepSize*FLogEveryBatches))/60,ffFixed,1,4)+' minutes.' +
      ' '+IntToStr(Epochs)+' epochs: ' + FloatToStrF( Epochs*totalTimeSeconds*(TrainingCnt/(FStepSize*FLogEveryBatches))/3600,ffFixed,1,4)+' hours.');

    MessageProc(
      'Epochs: '+IntToStr(FCurrentEpoch)+
      '. Working time: '+FloatToStrF(Round((Now() - globalStartTime)*2400)/100,ffFixed,4,2)+' hours.');

    if Assigned(FOnAfterEpoch) then FOnAfterEpoch(Self);
  end;

  if TestBestAtEnd and
    (TestCnt > 0) and
    Not(FShouldQuit) and
    (Assigned(FGetTestPair) or Assigned(FGetTestProc)) then
  begin
    if FileExists(filename) then
    begin
      MessageProc('Loading '+filename+' for final test.');
      FAvgWeight.LoadFromFile(filename);
      RunTest();
      WriteLn
      (
        CSVFile,
        'FINAL TEST',',',
        '',',',
        '',',',
        '',',',
        '',',',
        '',',',
        '',',',
        '',',',
        Round( (Now() - globalStartTime) * 24 * 60 * 60),',',
        TestRate:6:4,',',
        TestLoss:6:4,',',
        TestError:6:4
      );
    end;
  end;

  if FLoadBestAdEnd and FileExists(filename) then
  begin
    MessageProc('Loading best performing results '+filename+'.');
    FNN.LoadFromFile(filename);
  end
  else
  begin
    // Final weights are the averaged weights.
    FNN.CopyWeights(FAvgWeight);
  end;

  CloseFile(CSVFile);
  FMessageProc('Finished.');
  FreeMemory();
end;

procedure TNeuralDataLoadingFit.FitLoading(pNN: TNNet; TrainingCnt,
  ValidationCnt, TestCnt, pBatchSize, Epochs: integer; pGetTrainingProc,
  pGetValidationProc, pGetTestProc: TNNetGet2VolumesProc);
var
  vGetTrainingPair, vGetValidationPair, vGetTestPair: TNNetGetPairFn;
begin
  vGetTrainingPair := nil;
  vGetValidationPair := nil;
  vGetTestPair := nil;
  FGetTrainingProc := pGetTrainingProc;
  FGetValidationProc := pGetValidationProc;
  FGetTestProc := pGetTestProc;

  FitLoading(pNN, TrainingCnt, ValidationCnt, TestCnt, pBatchSize, Epochs,
    vGetTrainingPair, vGetValidationPair, vGetTestPair);

  FGetTrainingProc := nil;
  FGetValidationProc := nil;
  FGetTestProc := nil;
end;

function TNeuralFit.FitTrainingPair(Idx: integer; ThreadId: integer): TNNetVolumePair;
var
  ElementIdx: integer;
begin
  ElementIdx := Random(FTrainingVolumes.Count);
  FitTrainingPair := FTrainingVolumes[ElementIdx];
end;

function TNeuralFit.FitValidationPair(Idx: integer; ThreadId: integer): TNNetVolumePair;
begin
  FitValidationPair := FValidationVolumes[Idx];
end;

function TNeuralFit.FitTestPair(Idx: integer; ThreadId: integer): TNNetVolumePair;
begin
  FitTestPair := FTestVolumes[Idx];
end;

constructor TNeuralFit.Create();
begin
  inherited Create();
  FInferHitFn := nil;
  FDataAugmentationFn := nil;
  FLossFn := nil;
  {$IFDEF FPC}
  FGetTrainingPair := @Self.FitTrainingPair;
  FGetValidationPair := @Self.FitTestPair;
  FGetTestPair := @Self.FitTestPair;
  {$ELSE}
  FGetTrainingPair := Self.FitTrainingPair;
  FGetValidationPair := Self.FitTestPair;
  FGetTestPair := Self.FitTestPair;
  {$ENDIF}
end;

destructor TNeuralFit.Destroy();
begin
  inherited Destroy();
end;

procedure TNeuralFit.Fit(pNN: TNNet; pTrainingVolumes, pValidationVolumes,
  pTestVolumes: TNNetVolumePairList; pBatchSize, Epochs: integer);
var
  TrainingCnt, ValidationCnt, TestCnt: integer;
begin
  TrainingCnt := 0;
  ValidationCnt := 0;
  TestCnt := 0;

  FTrainingVolumes := pTrainingVolumes;
  FValidationVolumes := pValidationVolumes;
  FTestVolumes := pTestVolumes;

  if Assigned(FTrainingVolumes) then TrainingCnt := FTrainingVolumes.Count;
  if Assigned(FValidationVolumes) then ValidationCnt := FValidationVolumes.Count;
  if Assigned(FTestVolumes) then TestCnt := FTestVolumes.Count;

  {$IFDEF FPC}
  FitLoading(pNN, TrainingCnt, ValidationCnt, TestCnt,
    pBatchSize, Epochs, @Self.FitTrainingPair,
    @Self.FitValidationPair, @Self.FitTestPair);
  {$ELSE}
  FitLoading(pNN, TrainingCnt, ValidationCnt, TestCnt,
    pBatchSize, Epochs, Self.FitTrainingPair,
    Self.FitValidationPair, Self.FitTestPair);
  {$ENDIF}
end;

procedure TNeuralDataLoadingFit.RunNNThread(index, threadnum: integer);
var
  BlockSize, BlockSizeRest: integer;
  LocalNN: TNNet;
  vInput: TNNetVolume;
  vInputCopy: TNNetVolume;
  pOutput, vOutput: TNNetVolume;
  I: integer;
  CurrentLoss, CurrentError: TNeuralFloat;
  LocalHit, LocalMiss: integer;
  LocalTotalLoss, LocalErrorSum: TNeuralFloat;
  LocalTrainingPair: TNNetVolumePair;
  {$IFDEF DEBUG}
  InitialWeightSum, FinalWeightSum: TNeuralFloat;
  InitialInertia, FinalInertia: TNeuralFloat;
  {$ENDIF}
  CropSizeX, CropSizeY: integer;
  DepthCnt: integer;
  LocalChannelShiftRate: TNeuralFloat;
begin
  vInput     := TNNetVolume.Create();
  pOutput    := TNNetVolume.Create();
  vOutput    := TNNetVolume.Create();
  vInputCopy := TNNetVolume.Create();

  LocalHit := 0;
  LocalMiss := 0;
  LocalTotalLoss := 0;
  LocalErrorSum := 0;

  BlockSize := FBatchSize div FThreadNum;
  BlockSizeRest := FBatchSize mod FThreadNum;

  if (Index < BlockSizeRest) then Inc(BlockSize);

  LocalNN := FThreadNN[Index];
  LocalNN.CopyWeights(FNN);
  LocalNN.ClearTime();
  LocalNN.ClearDeltas();
  LocalNN.EnableDropouts(true);
  {$IFDEF DEBUG}
  InitialWeightSum := LocalNN.GetWeightSum() + LocalNN.GetBiasSum();
  InitialInertia := LocalNN.GetInertiaSum();
  {$ENDIF}
  for I := 1 to BlockSize do
  begin
    if FShouldQuit then Break;

    if Assigned(FGetTrainingPair) then
    begin
      LocalTrainingPair := FGetTrainingPair(I, Index);
      vInput.Copy( LocalTrainingPair.I );
      vOutput.Copy( LocalTrainingPair.O );
      vInput.Tag := LocalTrainingPair.I.Tag;
      vOutput.Tag := LocalTrainingPair.O.Tag;
    end
    else
    begin
      FGetTrainingProc(I, Index, vInput, vOutput)
    end;

    if Assigned(FDataAugmentationFn) then
    begin
      FDataAugmentationFn(vInput, Index);
    end
    else if FDataAugmentation then
    begin
      if FHasImgCrop then
      begin
        vInputCopy.CopyCropping(vInput, random(FMaxCropSize), random(FMaxCropSize), vInput.SizeX-FMaxCropSize, vInput.SizeY-FMaxCropSize);
        vInput.Copy(vInputCopy);
      end
      else if FHasResizing then
      begin
        CropSizeX := random(FMaxCropSize + 1);
        CropSizeY := random(FMaxCropSize + 1);
        vInputCopy.CopyCropping(vInput, random(CropSizeX), random(CropSizeY), vInput.SizeX-CropSizeX, vInput.SizeY-CropSizeY);
        vInput.CopyResizing(vInputCopy, vInput.SizeX, vInput.SizeY);
      end;

      if FChannelShiftRate > 0 then
      begin
        for DepthCnt := 0 to vInput.Depth - 1 do
        begin
          LocalChannelShiftRate := ((random(10000) - 5000) / 5000);
          LocalChannelShiftRate := 1 + (LocalChannelShiftRate * LocalChannelShiftRate);
          vInput.MulAtDepth(DepthCnt, LocalChannelShiftRate);
        end;
      end;

      if (vInput.Depth = 3) then
      begin
        if FHasMakeGray and (Random(1000) > 750) then
        begin
          vInput.MakeGray(FColorEncoding);
        end;
      end;

      if FHasFlipX and (Random(1000) > 500) then
      begin
        vInput.FlipX();
      end;

      if FHasFlipY and (Random(1000) > 500) then
      begin
        vInput.FlipY();
      end;
    end;

    LocalNN.Compute( vInput );
    LocalNN.GetOutput( pOutput );

    CurrentError := vOutput.SumDiff( pOutput );
    LocalErrorSum := LocalErrorSum + CurrentError;

    if (CurrentError > FMinBackpropagationError) or
      (
        (FCurrentTrainingError>0) and
        (CurrentError > FCurrentTrainingError*FMinBackpropagationErrorProportion)
      )
      then
    begin
      LocalNN.Backpropagate( vOutput );
    end;

    CurrentLoss := 0;
    if Assigned(FLossFn) then
    begin
      CurrentLoss := FLossFn(vOutput, pOutput, Index);
    end;

    LocalTotalLoss := LocalTotalLoss + CurrentLoss;

    if Assigned(FInferHitFn) then
    begin
      if FInferHitFn(vOutput, pOutput, Index) then
      begin
        Inc(LocalHit);
      end
      else
      begin
        Inc(LocalMiss);
      end;
    end;
  end; // of for

  if (Index and 1 = 0) and Not(FShouldQuit) then
  begin
    if Index + 1 < FThreadNum then
    begin
      while (FFinishedThread.FData[Index + 1] = 0) and Not(FShouldQuit) do;
      LocalNN.SumDeltasNoChecks(FThreadNN[Index + 1]);
      {$IFDEF FPC}
      FFinishedThread.FData[Index] += FFinishedThread.FData[Index + 1];
      {$ELSE}
      FFinishedThread.FData[Index] := FFinishedThread.FData[Index] +
        FFinishedThread.FData[Index + 1];
      {$ENDIF}
    end;
  end;
  FFinishedThread.FData[Index] := FFinishedThread.FData[Index] + 1;
  if (Index and 3 = 0) and Not(FShouldQuit) then
  begin
    if Index + 2 < FThreadNum then
    begin
      while (FFinishedThread.FData[Index + 2] = 0) and Not(FShouldQuit) do;
      LocalNN.SumDeltasNoChecks(FThreadNN[Index + 2]);
      {$IFDEF FPC}
      FFinishedThread.FData[Index] += FFinishedThread.FData[Index + 2];
      {$ELSE}
      FFinishedThread.FData[Index] := FFinishedThread.FData[Index] +
        FFinishedThread.FData[Index + 2];
      {$ENDIF}
    end;
  end;
  {$IFDEF DEBUG}
  FinalWeightSum := LocalNN.GetWeightSum() + LocalNN.GetBiasSum();
  FinalInertia := LocalNN.GetInertiaSum();
  if InitialWeightSum <> FinalWeightSum then
  begin
    FErrorProc('Weights changed from '+FloatToStr(FinalWeightSum)+' to '+FloatToStr(FinalWeightSum));
  end;
  if FinalInertia <> FinalInertia then
  begin
    FErrorProc('Inertia changed from '+FloatToStr(InitialInertia)+' to '+FloatToStr(FinalInertia));
  end;
  {$ENDIF}
  {$IFDEF HASTHREADS}EnterCriticalSection(FCritSec);{$ENDIF}
  FGlobalHit       := FGlobalHit  + LocalHit;
  FGlobalMiss      := FGlobalMiss + LocalMiss;
  FGlobalTotalLoss := FGlobalTotalLoss + LocalTotalLoss;
  FGlobalErrorSum  := FGlobalErrorSum  + LocalErrorSum;

  FNN.ForwardTime  := FNN.ForwardTime  + LocalNN.ForwardTime;
  FNN.BackwardTime := FNN.BackwardTime + LocalNN.BackwardTime;
  {$IFDEF Debug}
  if Index and 3 = 0 then FNN.SumDeltas(LocalNN);
  {$ELSE}
  if Index and 3 = 0 then FNN.SumDeltasNoChecks(LocalNN);
  {$ENDIF}
  {$IFDEF HASTHREADS}LeaveCriticalSection(FCritSec);{$ENDIF}
  vInputCopy.Free;
  vInput.Free;
  vOutput.Free;
  pOutput.Free;
end;

procedure TNeuralDataLoadingFit.TestNNThread(index, threadnum: integer);
var
  BlockSize: integer;
  LocalNN: TNNet;
  vInput: TNNetVolume;
  pOutput, vOutput, LocalFrequency: TNNetVolume;
  vInputCopy: TNNetVolume;
  sumOutput: TNNetVolume;
  I: integer;
  StartPos, FinishPos: integer;
  LocalHit, LocalMiss: integer;
  LocalTotalLoss, LocalErrorSum: TNeuralFloat;
  LocalTestPair: TNNetVolumePair;
  TotalDiv: TNeuralFloat;
begin
  vInput     := TNNetVolume.Create();
  pOutput    := TNNetVolume.Create();
  vOutput    := TNNetVolume.Create();
  sumOutput  := TNNetVolume.Create();
  vInputCopy := TNNetVolume.Create();
  LocalFrequency := TNNetVolume.Create();

  LocalHit := 0;
  LocalMiss := 0;
  LocalTotalLoss := 0;
  LocalErrorSum := 0;

  BlockSize := (FTestSize div FThreadNum) {$IFDEF MakeQuick}div 10{$ENDIF};
  StartPos  := BlockSize * index;
  FinishPos := BlockSize * (index + 1) - 1;

  LocalNN := FThreadNN[Index];
  LocalNN.CopyWeights(FAvgWeight);
  LocalNN.EnableDropouts(false);
  for I := StartPos to FinishPos - 1 do
  begin
    if FShouldQuit then Break;

    if Assigned(FLocalTestPair) then
    begin
      LocalTestPair := FLocalTestPair(I, Index);
      vInput.Copy(LocalTestPair.I);
      vOutput.Copy(LocalTestPair.O);
    end
    else
    begin
      FLocalTestProc(I, Index, vInput, vOutput);
    end;

    if FHasImgCrop then
    begin
      vInputCopy.CopyCropping(vInput, FMaxCropSize div 2, FMaxCropSize div 2, vInput.SizeX-FMaxCropSize, vInput.SizeY-FMaxCropSize);
      vInput.Copy(vInputCopy);
    end;

    LocalNN.Compute( vInput );
    LocalNN.GetOutput( pOutput );

    if FMultipleSamplesAtValidation then
    begin
      TotalDiv := 1;
      sumOutput.ReSize( pOutput );
      sumOutput.Copy( pOutput );

      if FHasFlipX then
      begin
        vInput.FlipX();
        TotalDiv := TotalDiv + 1;
        LocalNN.Compute( vInput );
        LocalNN.GetOutput( pOutput );
        sumOutput.Add( pOutput );
      end;

      if FHasFlipY then
      begin
        vInput.FlipY();
        TotalDiv := TotalDiv + 1;
        LocalNN.Compute( vInput );
        LocalNN.GetOutput( pOutput );
        sumOutput.Add( pOutput );
      end;

      if ((FMaxCropSize >= 2) and Not(FHasImgCrop)) then
      begin
        vInputCopy.CopyCropping(vInput, FMaxCropSize div 2, FMaxCropSize div 2, vInput.SizeX - FMaxCropSize, vInput.SizeY - FMaxCropSize);
        vInput.CopyResizing(vInputCopy, vInput.SizeX, vInput.SizeY);
        LocalNN.Compute( vInput );
        LocalNN.GetOutput( pOutput );
        sumOutput.Add( pOutput );
        TotalDiv := TotalDiv + 1;
      end;
      sumOutput.Divi(TotalDiv);

      pOutput.Copy(sumOutput);
    end;

    LocalErrorSum := LocalErrorSum + vOutput.SumDiff( pOutput );

    if Assigned(FInferHitFn) then
    begin
      if FInferHitFn(vOutput, pOutput, Index) then
      begin
        Inc(LocalHit);
      end
      else
      begin
        Inc(LocalMiss);
      end;
    end;

    if Assigned(FLossFn)
      then LocalTotalLoss := LocalTotalLoss + FLossFn(vOutput, pOutput, Index);
  end; // of for
  LocalNN.EnableDropouts(true);

  {$IFDEF HASTHREADS}EnterCriticalSection(FCritSec);{$ENDIF}
  FGlobalHit       := FGlobalHit + LocalHit;
  FGlobalMiss      := FGlobalMiss + LocalMiss;
  FGlobalTotalLoss := FGlobalTotalLoss + LocalTotalLoss;
  FGlobalErrorSum  := FGlobalErrorSum + LocalErrorSum;
  {$IFDEF HASTHREADS}LeaveCriticalSection(FCritSec);{$ENDIF}

  LocalFrequency.Free;
  vInputCopy.Free;
  sumOutput.Free;
  vInput.Free;
  vOutput.Free;
  pOutput.Free;
end;

procedure TNeuralDataLoadingFit.AllocateMemory(pNN: TNNet;
  pBatchSize: integer; pGetTrainingPair,
  pGetValidationPair, pGetTestPair: TNNetGetPairFn);
begin
  FRunning := true;
  FShouldQuit := false;
  FNN := pNN;
  FGetTrainingPair := pGetTrainingPair;
  FGetValidationPair := pGetValidationPair;
  FGetTestPair := pGetTestPair;
  {$IFNDEF HASTHREADS}
  FMaxThreadNum := 1;
  {$ENDIF}
  FCurrentEpoch := FInitialEpoch;
  FCurrentLearningRate := FInitialLearningRate;
  FThreadNum := Min(FMaxThreadNum, FDefaultThreadCount);
  FBatchSize := pBatchSize;
  if FBatchSize >= FThreadNum then
  begin
    FBatchSize := (FBatchSize div FThreadNum) * FThreadNum;
  end
  else if FBatchSize > 0 then
  begin
    FThreadNum := FBatchSize;
  end
  else
  begin
    FErrorProc('Batch size has to be bigger than zero.');
    FRunning := false;
    exit;
  end;

  if Not(Assigned(FGetTrainingPair)) and Not(Assigned(FGetTrainingProc)) then
  begin
    FErrorProc('Training function hasn''t been defined.');
    exit;
  end;
  FProcs := TNeuralThreadList.Create(FThreadNum);
  FStepSize := FBatchSize;
  if Assigned(FThreadNN) then FThreadNN.Free;
  FThreadNN := TNNetDataParallelism.Create(FNN, FThreadNum);
  {$IFDEF OpenCL}
  if (FPlatformId <> nil) and (FDeviceId <> nil) then
    FThreadNN.EnableOpenCL(FPlatformId, FDeviceId);
  {$ENDIF}
  FFinishedThread.Resize(1, 1, FThreadNum);
  FAvgWeights := nil;
  FAvgWeight := FNN.Clone();
  FThreadNN.SetLearningRate(FCurrentLearningRate, FInertia);
  FThreadNN.SetBatchUpdate(true);
  // in batch update mode, threaded NN should not apply L2 (L2 is applied in the main thread).
  FThreadNN.SetL2Decay(0);

  FNN.SetL2Decay(FL2Decay);
  FNN.SetLearningRate(FCurrentLearningRate, FInertia);
end;

procedure TNeuralDataLoadingFit.AllocateMemory(pNN: TNNet; pBatchSize: integer;
  pGetTrainingProc, pGetValidationProc,
  pGetTestProc: TNNetGet2VolumesProc);
var
  vGetTrainingPair, vGetValidationPair, vGetTestPair: TNNetGetPairFn;
begin
  vGetTrainingPair := nil;
  vGetValidationPair := nil;
  vGetTestPair := nil;
  FGetTrainingProc := pGetTrainingProc;
  FGetValidationProc := pGetValidationProc;
  FGetTestProc := pGetTestProc;
  AllocateMemory(pNN, pBatchSize, vGetTrainingPair, vGetValidationPair, vGetTestPair);
end;

procedure TNeuralDataLoadingFit.FreeMemory();
begin
  FProcs.Free;
  FGetTrainingPair := nil;
  FGetValidationPair := nil;
  FGetTestPair := nil;
  FreeAndNil(FAvgWeight);
  if Assigned(FAvgWeights) then FreeAndNil(FAvgWeights);
  FreeAndNil(FThreadNN);
  FRunning := false;
end;

procedure TNeuralDataLoadingFit.RunTrainingBatch();
var
  MaxDelta: TNeuralFloat;
begin
  FGlobalHit       := 0;
  FGlobalMiss      := 0;
  FGlobalTotalLoss := 0;
  FGlobalErrorSum  := 0;
  FFinishedThread.Fill(0);
  FNN.ClearTime();
  FNN.RefreshDropoutMask();
  {$IFDEF HASTHREADS}
  //ProcThreadPool.DoParallel(@RunNNThread, 0, FThreadNN.Count-1, Nil, FThreadNN.Count);
  FProcs.StartProc({$IFDEF FPC}@RunNNThread{$ELSE}RunNNThread{$ENDIF});
  {$ELSE}
  RunNNThread(0, 1);
  {$ENDIF}
  Optimize();
end;

procedure TNeuralDataLoadingFit.RunValidationBatch(ValidationSize: integer);
begin
  FGlobalHit       := 0;
  FGlobalMiss      := 0;
  FGlobalTotalLoss := 0;
  FGlobalErrorSum  := 0;
  FTestSize        := ValidationSize;
  FLocalTestPair   := FGetValidationPair;
  FLocalTestProc   := FGetValidationProc;
  FMessageProc('Starting Validation.');
  {$IFDEF HASTHREADS}
  //ProcThreadPool.DoParallel(@TestNNThread, 0, FThreadNN.Count-1, Nil, FThreadNN.Count);
  FProcs.StartProc({$IFDEF FPC}@TestNNThread{$ELSE}TestNNThread{$ENDIF});
  {$ELSE}
  TestNNThread(0, 1);
  {$ENDIF}
  FGlobalTotal := (FGlobalHit + FGlobalMiss);
end;

procedure TNeuralDataLoadingFit.RunTestBatch(TestSize: integer);
begin
  FGlobalHit       := 0;
  FGlobalMiss      := 0;
  FGlobalTotalLoss := 0;
  FGlobalErrorSum  := 0;
  FTestSize        := TestSize;
  FLocalTestPair   := FGetTestPair;
  FLocalTestProc   := FGetTestProc;
  FMessageProc('Starting Testing.');
  {$IFDEF HASTHREADS}
  //ProcThreadPool.DoParallel(@TestNNThread, 0, FThreadNN.Count-1, Nil, FThreadNN.Count);
  FProcs.StartProc({$IFDEF FPC}@TestNNThread{$ELSE}TestNNThread{$ENDIF});
  {$ELSE}
  TestNNThread(0, 1);
  {$ENDIF}
  FGlobalTotal := (FGlobalHit + FGlobalMiss);
end;

procedure TNeuralDataLoadingFit.EnableMonopolarHitComparison();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}MonopolarCompare;
end;

procedure TNeuralDataLoadingFit.EnableBipolarHitComparison();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}BipolarCompare;
end;

procedure TNeuralDataLoadingFit.EnableBipolar99HitComparison();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}BipolarCompare99;
end;

procedure TNeuralDataLoadingFit.EnableClassComparison();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}ClassCompare;
end;

procedure TNeuralDataLoadingFit.EnableMultiClassComparison();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}MultiClassCompare;
end;

procedure TNeuralDataLoadingFit.EnableClassComparisonInFirstPixel();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}ClassCompareOnFirstPixel;
end;

procedure TNeuralDataLoadingFit.EnableClassComparisonInLastPixel();
begin
  FInferHitFn := {$IFDEF FPC}@{$ENDIF}ClassCompareOnLastPixel;
end;

procedure TNeuralDataLoadingFit.EnableDefaultLoss();
begin
  FLossFn := {$IFDEF FPC}@{$ENDIF}DefaultLossFn;
end;

procedure TNeuralDataLoadingFit.EnableMultiClassLoss;
begin
  FLossFn := {$IFDEF FPC}@{$ENDIF}MultiClassLossFn;
end;

procedure TNeuralDataLoadingFit.EnableDefaultLossInFirstPixel();
begin
  FLossFn := {$IFDEF FPC}@{$ENDIF}DefaultLossInFirstPixelFn;
end;

procedure TNeuralDataLoadingFit.EnableDefaultLossInLastPixel();
begin
  FLossFn := {$IFDEF FPC}@{$ENDIF}DefaultLossInLastPixelFn;
end;

procedure TNeuralDataLoadingFit.EnableDefaultImageTreatment();
begin
  inherited EnableDefaultImageTreatment();
  EnableClassComparison();
  EnableDefaultLoss();
end;

{ TNeuralOptimizer }

procedure TNeuralOptimizer.ReSet;
begin
  // This method may be implemented in descending classes.
end;

procedure TNeuralOptimizer.SetNN(pNN: TNNet; pFit: TNeuralFitBase);
begin
  FNN := pNN;
  FFit := pFit;
  FMessageProc := pFit.MessageProc;
  FErrorProc := pFit.ErrorProc;
end;

procedure TNeuralOptimizer.ForceDeltaLimists();
var
  MaxDelta: TNeuralFloat;
begin
  if FFit.ClipNorm > 0 then
  begin
    FNN.NormalizeNormPerLayer(FFit.ClipNorm);
  end else if FFit.FClipDelta > 0 then
  begin
    //MaxDelta := FNN.ForceMaxAbsoluteDelta(FFit.FClipDelta);
    MaxDelta := FNN.NormalizeMinMaxAbsoluteDeltaPerLayer(0, FFit.FClipDelta);
  end
  else
  begin
    //FNN.NormalizeMaxAbsoluteDeltaPerNeuron(FCurrentLearningRate);
    //MaxDelta := FNN.NormalizeMinMaxAbsoluteDeltaPerLayer(FCurrentLearningRate, FCurrentLearningRate);
    MaxDelta := FNN.NormalizeMaxAbsoluteDelta();
    if MaxDelta < 1 then
    begin
      MessageProc('Deltas have been multiplied by: '+FloatToStr(MaxDelta)+'.'+
        ' Max delta on layer: '+IntToStr(FNN.MaxDeltaLayer)+' - '+
        FNN.Layers[FNN.MaxDeltaLayer].ClassName+'.');
    end;
  end;
end;

{ TNeuralOptimizerSGD }

procedure TNeuralOptimizerSGD.Reset();
begin
  inherited Reset;
  FNN.ClearInertia();
end;

procedure TNeuralOptimizerSGD.Optimize();
begin
  ForceDeltaLimists();
  FNN.UpdateWeights();
end;

{ TNeuralOptimizerAdam }

constructor TNeuralOptimizerAdam.Create(Beta1: TNeuralFloat;
  Beta2: TNeuralFloat; Epsilon: TNeuralFloat);
begin
  inherited Create();
  FBeta1 := Beta1;
  FBeta2 := Beta2;
  FEpsilon := Epsilon;
  FAdamInitialized := false;
end;

function TNeuralOptimizerAdam.InitAdam(Beta1, Beta2, Epsilon: TNeuralFloat
  ): TNNetLayer;
var
  LayerCnt: integer;
begin
  for LayerCnt := 0 to FNN.GetLastLayerIdx() do
  begin
    FNN.Layers[LayerCnt].InitAdam(Beta1, Beta2, Epsilon);
  end;
  Result := FNN.GetLastLayer();
end;

procedure TNeuralOptimizerAdam.Optimize();
begin
  if not(FAdamInitialized) then
  begin
    ReSet();
    FAdamInitialized := true;
  end;
  FNN.CalcAdamDelta();
  ForceDeltaLimists();
  FNN.UpdateWeightsAdam();
end;

procedure TNeuralOptimizerAdam.ReSet;
begin
  inherited ReSet;
  InitAdam(FBeta1, FBeta2, FEpsilon);
end;

{ TNeuralFitBase }
constructor TNeuralFitBase.Create();
begin
  inherited Create();
  {$IFDEF OpenCL}
  DisableOpenCL();
  {$ENDIF}
  FFinishedThread := TNNetVolume.Create();
  {$IFDEF HASTHREADS}
  FMaxThreadNum := NeuralDefaultThreadCount();
    //{$IFDEF OpenCL}
    // This optimization works very well on some systems but not all :-(
    // This optimization fails on google colab.
    //if FMaxThreadNum <=8 then
    //FMaxThreadNum := ProcThreadPool.MaxThreadCount * 2;
    //{$ENDIF}
  NeuralInitCriticalSection(FCritSec);
  {$ELSE}
  FMaxThreadNum := 1;
  {$ENDIF}
  FDefaultThreadCount := FMaxThreadNum;
  FDataAugmentation := true;
  FMultipleSamplesAtValidation := true;
  FVerbose := true;
  FStaircaseEpochs := 1;
  FStepSize := 1;
  FAvgWeightEpochCount := 10;
  FLearningRateDecay := 0.01;
  FInitialLearningRate := 0.001;
  FCyclicalLearningRateLen := 0; // not cyclical by default.
  FInitialEpoch := 0;
  FMinBackpropagationError := 0;
  FMinBackpropagationErrorProportion := 0.25;
  FInertia := 0.9;
  FClipDelta := 0.0;
  FClipNorm := 1.0;
  FFileNameBase := 'autosave';
  FL2Decay := 0.0000001;
  FTargetAccuracy := 1;
  FCustomLearningRateScheduleFn := nil;
  FCustomLearningRateScheduleObjFn := nil;
  FOnAfterStep := nil;
  FOnAfterEpoch := nil;
  FOnStart := nil;
  FTrainingAccuracy := 0;
  FValidationAccuracy := 0;
  FTestAccuracy := 0;
  FRunning := false;
  FShouldQuit := false;
  FCurrentEpoch := 0;
  FCurrentStep := 0;
  FLoadBestAdEnd := True;
  FTestBestAtEnd := True;
  FLogEveryBatches := 10;
  FOptimizer := nil;
  FOptimizerOwned := false;
  FSaveBest := SaveBestAccuracy;
end;

destructor TNeuralFitBase.Destroy();
begin
  if FOptimizerOwned and Assigned(FOptimizer) then FOptimizer.Free;
  {$IFDEF HASTHREADS}
  NeuralDoneCriticalSection(FCritSec);
  {$ENDIF}
  FFinishedThread.Free;
  inherited Destroy();
end;

procedure TNeuralFitBase.WaitUntilFinished;
begin
  FShouldQuit := true;
  while FRunning do
  begin
    Sleep(1);
  end;
end;

{$IFDEF OpenCL}
procedure TNeuralFitBase.DisableOpenCL();
begin
  FPlatformId := nil;
  FDeviceId := nil;
end;

procedure TNeuralFitBase.EnableOpenCL(platform_id: cl_platform_id;
  device_id: cl_device_id);
begin
  FPlatformId := platform_id;
  FDeviceId := device_id;
end;
{$ENDIF}

procedure TNeuralFitBase.CheckLearningRate(iEpochCount: integer);
var
  iStairCount: integer;
  fNewLearningRate: single;
begin
  if FCyclicalLearningRateLen > 0 then
  begin
    iEpochCount := iEpochCount mod FCyclicalLearningRateLen;
  end;
  if (FLearningRateDecay >= 0.5) and (FLearningRateDecay <= 1) then
  begin
    // This is a hack for backward compatibility. Weight decays should be
    // expressed with 0.01 and not 0.99
    FLearningRateDecay := 1 - FLearningRateDecay;
    if FVerbose then
    MessageProc
    (
      'Learning rate decay set to:'+FloatToStrF(FLearningRateDecay,ffFixed,7,5)
    );
  end;
  if Assigned(FCustomLearningRateScheduleFn) then
  begin
    fNewLearningRate := FCustomLearningRateScheduleFn(iEpochCount);
  end
  else if Assigned(FCustomLearningRateScheduleObjFn) then
  begin
    fNewLearningRate := FCustomLearningRateScheduleObjFn(iEpochCount);
  end
  else if FStaircaseEpochs > 1 then
  begin
    iStairCount := iEpochCount div FStaircaseEpochs;
    fNewLearningRate := (fInitialLearningRate * power(1-FLearningRateDecay, iStairCount * FStaircaseEpochs));
  end
  else
  begin
    fNewLearningRate := (fInitialLearningRate * power(1-FLearningRateDecay,iEpochCount));
  end;
  if ( fNewLearningRate <> FCurrentLearningRate ) then
  begin
    FCurrentLearningRate := fNewLearningRate;
    FThreadNN.SetLearningRate(FCurrentLearningRate, FInertia);
    FNN.SetLearningRate(FCurrentLearningRate, FInertia);
    if Assigned(FOptimizer) then
    begin
      if (not Assigned(FOptimizer.FNN)) then
      begin
        FOptimizer.SetNN(FNN, Self);
      end;
      FOptimizer.ReSet();
    end;
    if FVerbose then
    MessageProc
    (
      'Learning rate set to: ' + FloatToStrF(FCurrentLearningRate, ffFixed, 7, 5)
    );
  end;
end;

procedure TNeuralFitBase.SetOptimizer(pOptimizer: TNeuralOptimizer);
begin
  if FOptimizerOwned and Assigned(FOptimizer) then FOptimizer.Free;
  FOptimizer := pOptimizer;
  FOptimizerOwned := false;
  FOptimizer.SetNN(FNN, Self);
end;

procedure TNeuralFitBase.SetClipDelta(Value: TNeuralFloat);
begin
  FClipDelta := Value;
  FClipNorm  := 0.0;
end;

procedure TNeuralFitBase.SetClipNorm(Value: TNeuralFloat);
begin
  FClipDelta := 0.0;
  FClipNorm  := Value;
end;

{ TNeuralImageFit }

constructor TNeuralImageFit.Create();
begin
  inherited Create();
  FChannelShiftRate := 0;
  FColorEncoding := 0;
  FHasImgCrop := false;
  FHasResizing := True;
  FHasFlipX := true;
  FHasFlipY := false;
  FHasMakeGray := true;
  FIsSoftmax := true;
  FMaxCropSize := 8;
  FMinBackpropagationError := 0.2;
  FMinBackpropagationErrorProportion := 0.25;
  FMultipleSamplesAtValidation := true;
  FTrainingSampleProcessedCnt := TNNetVolume.Create;
end;

destructor TNeuralImageFit.Destroy();
begin
  FTrainingSampleProcessedCnt.Free;
  inherited Destroy;
end;

procedure TNeuralImageFit.Fit(pNN: TNNet;
  pImgVolumes, pImgValidationVolumes, pImgTestVolumes: TNNetVolumeList;
  pNumClasses, pBatchSize, Epochs: integer);
var
  TestError, TestLoss, TestRate: TNeuralFloat;
  globalStartTime: double;
  procedure RunTest();
  begin
          FWorkingVolumes := FImgTestVolumes;
          FGlobalHit       := 0;
          FGlobalMiss      := 0;
          FGlobalTotalLoss := 0;
          FGlobalErrorSum  := 0;
          FMessageProc('Starting Testing.');
          {$IFDEF HASTHREADS}
          //ProcThreadPool.DoParallel(@TestNNThread, 0, FThreadNN.Count-1, Nil, FThreadNN.Count);
          FProcs.StartProc({$IFDEF FPC}@TestNNThread{$ELSE}TestNNThread{$ENDIF});
          {$ELSE}
          TestNNThread(0, 1);
          {$ENDIF}

          FGlobalTotal := (FGlobalHit + FGlobalMiss);
          if (FGlobalTotal > 0) then
          begin
            TestRate  := FGlobalHit / FGlobalTotal;
            TestLoss  := FGlobalTotalLoss / FGlobalTotal;
            TestError := FGlobalErrorSum / FGlobalTotal;
            FTestAccuracy := TestRate;
          end;

          if (FGlobalTotal > 0) and (FVerbose) then
          begin
            FMessageProc(
              'Epochs: ' + IntToStr(FCurrentEpoch) +
              ' Examples seen:' + IntToStr(FCurrentEpoch * FImgVolumes.Count) +
              ' Test Accuracy: ' + FloatToStrF(TestRate,ffFixed,6,4) +
              ' Test Error: ' + FloatToStrF(TestError,ffFixed,6,4) +
              ' Test Loss: ' + FloatToStrF(TestLoss,ffFixed,6,4) +
              ' Total time: ' + FloatToStrF(((Now() - globalStartTime)) * 24 * 60,ffFixed,6,2) +
              'min'
            );
          end;
  end;
var
  I: integer;
  startTime, totalTimeSeconds: double;
  fileName, FileNameCSV: string;
  CurrentError, CurrentLoss: TNeuralFloat;
  ValidationRate: TNeuralFloat;
  LocalHasValidation: boolean;
  CSVFile: TextFile;
  CurrentAccuracy, AccuracyWithInertia: TNeuralFloat;
  MaxDelta: TNeuralFloat;
  ValidationRecord: TNeuralFloat;
begin
  FRunning := true;
  FShouldQuit := false;
  FNN := pNN;
  {$IFNDEF HASTHREADS}
  FMaxThreadNum := 1;
  {$ENDIF}
  FCurrentEpoch := FInitialEpoch;
  FCurrentStep := 0;
  FCurrentLearningRate := FInitialLearningRate;
  FImgVolumes := pImgVolumes;
  FTrainingSampleProcessedCnt.Resize(FImgVolumes.Count);
  FImgValidationVolumes := pImgValidationVolumes;
  FImgTestVolumes := pImgTestVolumes;
  LocalHasValidation := False;
  if Assigned(FImgValidationVolumes) then
  begin
    if FImgValidationVolumes.Count>0 then
    begin
      LocalHasValidation := True;
    end;
  end;
  FThreadNum := Min(FMaxThreadNum, FDefaultThreadCount);
  FBatchSize := pBatchSize;
  FMaxEpochs := Epochs;
  if FBatchSize >= FThreadNum then
  begin
    FBatchSize := (FBatchSize div FThreadNum) * FThreadNum;
  end
  else if FBatchSize > 0 then
  begin
    FThreadNum := FBatchSize;
  end
  else
  begin
    FErrorProc('Batch size has to be bigger than zero.');
    FRunning := false;
    exit;
  end;
  FProcs := TNeuralThreadList.Create(FThreadNum);
  FStepSize := FBatchSize;
  if Assigned(FThreadNN) then FThreadNN.Free;
  FThreadNN := TNNetDataParallelism.Create(FNN, FThreadNum);
  {$IFDEF OpenCL}
  if (FPlatformId <> nil) and (FDeviceId <> nil) then
    FThreadNN.EnableOpenCL(FPlatformId, FDeviceId);
  {$ENDIF}
  FFinishedThread.Resize(1, 1, FThreadNum);
  FNumClasses := pNumClasses;
  AccuracyWithInertia := 100 / FNumClasses;
  CurrentError := 0;
  CurrentLoss := 0;
  ValidationRate := 0;
  FValidationLoss := 0;
  FValidationError := 0;
  TestRate := 0;
  TestLoss := 0;
  TestError := 0;
  if FSaveBest = SaveBestAccuracy
  then ValidationRecord := 0
  else ValidationRecord := 100;
  totalTimeSeconds := 0;

  FMessageProc('File name is: ' + FFileNameBase);

  FileNameCSV := FFileNameBase + '.csv';
  FileName := FFileNameBase + '.nn';

  AssignFile(CSVFile, FileNameCSV);
  ReWrite(CSVFile);
  WriteLn(CSVFile, 'epoch,training accuracy,training loss,training error,validation accuracy,validation loss,validation error,learning rate,time,test accuracy,test loss,test error');

  FAvgWeights := nil;
  FAvgWeight := FNN.Clone();

  if FVerbose then
  begin
    MessageProc(
      'Learning rate:' + FloatToStrF(FCurrentLearningRate,ffFixed,8,6) +
      ' Clip norm:' + FloatToStrF(FClipNorm,ffFixed,8,6) +
      ' Clip delta:' + FloatToStrF(FClipDelta,ffFixed,8,6) +
      ' L2 decay:' + FloatToStrF(FL2Decay,ffFixed,8,6) +
      ' Inertia:' + FloatToStrF(FInertia,ffFixed,8,6) +
      ' Batch size:' + IntToStr(FBatchSize) +
      ' Step size:' + IntToStr(FStepSize) +
      ' Staircase ephocs:' + IntToStr(FStaircaseEpochs) +
      ' Min backprop error and proportion:' +
        FloatToStrF(FMinBackpropagationError,ffFixed,4,2)+' '+
        FloatToStrF(FMinBackpropagationErrorProportion,ffFixed,4,2)
    );
    if Assigned(FImgVolumes) then MessageProc('Training images: '+IntToStr(FImgVolumes.Count));
    if Assigned(FImgValidationVolumes) then MessageProc('Validation images: '+IntToStr(FImgValidationVolumes.Count));
    if Assigned(FImgTestVolumes) then MessageProc('Test images: '+IntToStr(FImgTestVolumes.Count));
  end;

  FThreadNN.SetLearningRate(FCurrentLearningRate, FInertia);
  FThreadNN.SetBatchUpdate(true);
  // in batch update mode, threaded NN should not apply L2 (L2 is applied in the main thread).
  FThreadNN.SetL2Decay(0);

  FNN.SetL2Decay(FL2Decay);
  FNN.SetLearningRate(FCurrentLearningRate, FInertia);

  if FVerbose then
  begin
    MessageProc('Computing...');
  end;
  if Assigned(FOnStart) then FOnStart(Self);
  globalStartTime := Now();
  while ( (FMaxEpochs > FCurrentEpoch) and Not(FShouldQuit) ) do
  begin
    FGlobalErrorSum := 0;
    startTime := Now();
    CheckLearningRate(FCurrentEpoch);
    // the following for command will run 1 epoch
    for I := 1 to (FImgVolumes.Count div FStepSize) {$IFDEF MakeQuick}div 10{$ENDIF} do
    begin
      if (FShouldQuit) then break;
      FGlobalHit       := 0;
      FGlobalMiss      := 0;
      FGlobalTotalLoss := 0;
      FGlobalErrorSum  := 0;
      FFinishedThread.Fill(0);
      FNN.ClearTime();
      FNN.RefreshDropoutMask();
      {$IFDEF HASTHREADS}
      //ProcThreadPool.DoParallel(@RunNNThread, 0, FThreadNN.Count-1, Nil, FThreadNN.Count);
      FProcs.StartProc({$IFDEF FPC}@RunNNThread{$ELSE}RunNNThread{$ENDIF});
      {$ELSE}
      RunNNThread(0, 1);
      {$ENDIF}
      Optimize();
      FGlobalTotal := (FGlobalHit + FGlobalMiss);
      if (FGlobalTotal > 0) then
      begin
        CurrentError := FGlobalErrorSum / FGlobalTotal;
        FCurrentTrainingError := CurrentError;
        CurrentLoss  := FGlobalTotalLoss / FGlobalTotal;
        CurrentAccuracy := (FGlobalHit*100) div FGlobalTotal;
        if (FCurrentEpoch = FInitialEpoch) and (I = 1) then
        begin
          AccuracyWithInertia := CurrentAccuracy;
        end else if (FStepSize < 1280) then
        begin
          AccuracyWithInertia := AccuracyWithInertia*0.99 + CurrentAccuracy*0.01;
        end
        else if (FStepSize < 5120) then
        begin
          AccuracyWithInertia := AccuracyWithInertia*0.9 + CurrentAccuracy*0.1;
        end
        else
        begin
          AccuracyWithInertia := CurrentAccuracy;
        end;
        FTrainingAccuracy := AccuracyWithInertia/100;
      end;

      if ( (FGlobalTotal > 0) and (I mod FLogEveryBatches = 0) ) then
      begin
        totalTimeSeconds := (Now() - startTime) * 24 * 60 * 60;
        if FVerbose then MessageProc
        (
          IntToStr((FGlobalHit + FGlobalMiss) * I + FCurrentEpoch*FImgVolumes.Count) +
          ' Examples seen. Accuracy: ' + FloatToStrF(FTrainingAccuracy,ffFixed,6,4) +
          ' Error: ' + FloatToStrF(CurrentError,ffFixed,10,5) +
          ' Loss: ' + FloatToStrF(CurrentLoss,ffFixed,7,5) +
          ' Threads: ' + IntToStr(FThreadNum) +
          ' Forward time: ' + FloatToStrF(FNN.ForwardTime * 24 * 60 * 60,ffFixed,6,2)+'s' +
          ' Backward time: ' + FloatToStrF(FNN.BackwardTime * 24 * 60 * 60,ffFixed,6,2)+'s' +
          ' Step time: ' + FloatToStrF(totalTimeSeconds,ffFixed,6,2) + 's'
        );

        startTime := Now();
      end;
      if Assigned(FOnAfterStep) then FOnAfterStep(Self);
      Inc(FCurrentStep);
    end; // of epoch
    {$IFDEF Debug}
    FMessageProc(
      IntToStr(FTrainingSampleProcessedCnt.GetValueCount(0)) +
      ' of samples haven''t been processed.');
    {$ENDIF}

    Inc(FCurrentEpoch);

    if not Assigned(FAvgWeights) then
    begin
      FAvgWeight.CopyWeights(FNN);
      if FAvgWeightEpochCount > 1
      then FAvgWeights := TNNetDataParallelism.Create(FNN, FAvgWeightEpochCount)
      else FAvgWeights := TNNetDataParallelism.Create(FNN, 1)
    end;

    if Not(FShouldQuit) then
    begin
      if FAvgWeightEpochCount > 1 then
      begin
        FAvgWeights.ReplaceAtIdxAndUpdateWeightAvg(FCurrentEpoch mod FAvgWeightEpochCount, FNN, FAvgWeight);
      end
      else
      begin
        FAvgWeight.CopyWeights(FNN);
      end;

      if LocalHasValidation and Not(FShouldQuit) then
      begin
        FWorkingVolumes := FImgValidationVolumes;
        FGlobalHit       := 0;
        FGlobalMiss      := 0;
        FGlobalTotalLoss := 0;
        FGlobalErrorSum  := 0;
        FMessageProc('Starting Validation.');
        {$IFDEF HASTHREADS}
        //ProcThreadPool.DoParallel(@TestNNThread, 0, FThreadNN.Count-1, Nil, FThreadNN.Count);
        FProcs.StartProc({$IFDEF FPC}@TestNNThread{$ELSE}TestNNThread{$ENDIF});
        {$ELSE}
        TestNNThread(0, 1);
        {$ENDIF}

        FGlobalTotal := (FGlobalHit + FGlobalMiss);
        if (FGlobalTotal > 0) then
        begin
          ValidationRate  := FGlobalHit / FGlobalTotal;
          FValidationLoss  := FGlobalTotalLoss / FGlobalTotal;
          FValidationError := FGlobalErrorSum / FGlobalTotal;
          FValidationAccuracy := ValidationRate;
        end;

        if (FSaveBest = SaveBestAccuracy) then
        begin
          if (ValidationRate > ValidationRecord) then
          begin
            ValidationRecord := ValidationRate;
            FMessageProc('VALIDATION RECORD! Saving NN at '+fileName);
            FAvgWeight.SaveToFile(fileName);
          end;
        end;

        if (FSaveBest = SaveBestLoss) then
        begin
          if (FValidationLoss < ValidationRecord) then
          begin
            ValidationRecord := FValidationLoss;
            FMessageProc('VALIDATION RECORD! Saving NN at '+fileName);
            FAvgWeight.SaveToFile(fileName);
          end;
        end;

        if (FGlobalTotal > 0) and (FVerbose) then
        begin
          FMessageProc(
            'Epochs: ' + IntToStr(FCurrentEpoch) +
            ' Examples seen:' + IntToStr(FCurrentEpoch * FImgVolumes.Count) +
            ' Validation Accuracy: ' + FloatToStrF(ValidationRate,ffFixed,6,4) +
            ' Validation Error: ' + FloatToStrF(FValidationError,ffFixed,6,4) +
            ' Validation Loss: ' + FloatToStrF(FValidationLoss,ffFixed,6,4) +
            ' Total time: ' + FloatToStrF(((Now() - globalStartTime)) * 24 * 60,ffFixed,6,2) +
            'min'
          );
        end;

        if (ValidationRate >= FTargetAccuracy) then
        begin
          FMessageProc('ValidationRate passed TargetAccuracy.');
          FShouldQuit := true;
          break;
        end;
      end;// Assigned(FImgValidationVolumes)

      if Not(LocalHasValidation) then
      begin
        FMessageProc('Saving NN at '+fileName);
        FAvgWeight.SaveToFile(fileName);
      end;

      if (FCurrentEpoch mod FThreadNN.Count = 0) and (FVerbose) then
      begin
        FThreadNN[0].DebugWeights();
      end;

      if Assigned(FImgTestVolumes) and Not(FShouldQuit) then
      begin
        if ( (FCurrentEpoch mod 10 = 0) and (FCurrentEpoch > 0) ) then
        begin
          RunTest();
        end;
        if (TestRate >= FTargetAccuracy) then
        begin
          FMessageProc('TestRate passed TargetAccuracy.');
          FShouldQuit := true;
          break;
        end;
      end;

      if ( (FCurrentEpoch mod 10 = 0) and (FCurrentEpoch > 0) ) then
      begin
        WriteLn
        (
          CSVFile,
          FCurrentEpoch,',',
          (AccuracyWithInertia/100):6:4,',',
          CurrentLoss:6:4,',',
          CurrentError:6:4,',',
          ValidationRate:6:4,',',
          FValidationLoss:6:4,',',
          FValidationError:6:4,',',
          FCurrentLearningRate:9:7,',',
          Round( (Now() - globalStartTime) * 24 * 60 * 60),',',
          TestRate:6:4,',',
          TestLoss:6:4,',',
          TestError:6:4
        );
      end
      else
      begin
        WriteLn
        (
          CSVFile,
          FCurrentEpoch,',',
          (AccuracyWithInertia/100):6:4,',',
          CurrentLoss:6:4,',',
          CurrentError:6:4,',',
          ValidationRate:6:4,',',
          FValidationLoss:6:4,',',
          FValidationError:6:4,',',
          FCurrentLearningRate:9:7,',',
          Round( (Now() - globalStartTime) * 24 * 60 * 60),',,,'
        );
      end;
      if Assigned(FOnAfterEpoch) then FOnAfterEpoch(Self);

      CloseFile(CSVFile);
      AssignFile(CSVFile, FileNameCSV);
      Append(CSVFile);

      MessageProc(
        'Epoch time: ' + FloatToStrF( totalTimeSeconds*(pImgVolumes.Count/(FStepSize*FLogEveryBatches))/60,ffFixed,1,4)+' minutes.' +
        ' '+IntToStr(Epochs)+' epochs: ' + FloatToStrF( Epochs*totalTimeSeconds*(pImgVolumes.Count/(FStepSize*FLogEveryBatches))/3600,ffFixed,1,4)+' hours.');

      MessageProc(
        'Epochs: '+IntToStr(FCurrentEpoch)+
        '. Working time: '+FloatToStrF(Round((Now() - globalStartTime)*2400)/100,ffFixed,4,2)+' hours.');
    end;
  end;

  if TestBestAtEnd and Assigned(FImgTestVolumes) and Not(FShouldQuit) then
  begin
    if FileExists(filename) then
    begin
      MessageProc('Loading '+filename+' for final test.');
      FAvgWeight.LoadFromFile(filename);
      RunTest();
      WriteLn
      (
        CSVFile,
        'FINAL TEST',',',
        '',',',
        '',',',
        '',',',
        '',',',
        '',',',
        '',',',
        '',',',
        Round( (Now() - globalStartTime) * 24 * 60 * 60),',',
        TestRate:6:4,',',
        TestLoss:6:4,',',
        TestError:6:4
      );
    end;
  end;

  if FLoadBestAdEnd and FileExists(filename) then
  begin
    MessageProc('Loading best performing results '+filename+'.');
    FNN.LoadFromFile(filename);
  end
  else
  begin
    // Final weights are the averaged weights.
    FNN.CopyWeights(FAvgWeight);
  end;

  FProcs.Free;
  FreeAndNil(FAvgWeight);
  if Assigned(FAvgWeights) then FreeAndNil(FAvgWeights);
  FreeAndNil(FThreadNN);
  CloseFile(CSVFile);
  FMessageProc('Finished.');
  FRunning := false;
end;

procedure TNeuralImageFit.RunNNThread(index, threadnum: integer);
var
  BlockSize, BlockSizeRest, CropSizeX, CropSizeY: integer;
  LocalNN: TNNet;
  ImgInput, ImgInputCp: TNNetVolume;
  pOutput, vOutput: TNNetVolume;
  I, ImgIdx: integer;
  OutputValue, CurrentLoss: TNeuralFloat;
  LocalHit, LocalMiss: integer;
  LocalTotalLoss, LocalErrorSum, CurrentError: TNeuralFloat;
  DepthCnt: integer;
  LocalChannelShiftRate: TNeuralFloat;
begin
  ImgInput := TNNetVolume.Create();
  ImgInputCp := TNNetVolume.Create();
  pOutput := TNNetVolume.Create(FNumClasses,1,1);
  vOutput := TNNetVolume.Create(FNumClasses,1,1);

  LocalHit := 0;
  LocalMiss := 0;
  LocalTotalLoss := 0;
  LocalErrorSum := 0;

  BlockSize := FBatchSize div FThreadNum;
  BlockSizeRest := FBatchSize mod FThreadNum;

  if (Index < BlockSizeRest) then Inc(BlockSize);

  LocalNN := FThreadNN[Index];
  LocalNN.CopyWeights(FNN);
  LocalNN.ClearTime();
  LocalNN.ClearDeltas();
  LocalNN.EnableDropouts(true);
  for I := 1 to BlockSize do
  begin
    if (FShouldQuit) then Break;
    ImgIdx := Random(FImgVolumes.Count);
    ImgIdx := FTrainingSampleProcessedCnt.GetSmallestIdxInRange(ImgIdx, 100);
    FTrainingSampleProcessedCnt.FData[ImgIdx] := FTrainingSampleProcessedCnt.FData[ImgIdx] + 1;

    if FDataAugmentation then
    begin
      if FHasImgCrop then
      begin
        ImgInput.CopyCropping(FImgVolumes[ImgIdx], random(FMaxCropSize), random(FMaxCropSize), FImgVolumes[ImgIdx].SizeX-FMaxCropSize, FImgVolumes[ImgIdx].SizeY-FMaxCropSize);
      end
      else if FHasResizing then
      begin
        CropSizeX := random(FMaxCropSize + 1);
        CropSizeY := random(FMaxCropSize + 1);
        ImgInputCp.CopyCropping(FImgVolumes[ImgIdx], random(CropSizeX), random(CropSizeY),FImgVolumes[ImgIdx].SizeX-CropSizeX, FImgVolumes[ImgIdx].SizeY-CropSizeY);
        ImgInput.CopyResizing(ImgInputCp, FImgVolumes[ImgIdx].SizeX, FImgVolumes[ImgIdx].SizeY);
      end
      else
      begin
        ImgInput.Copy(FImgVolumes[ImgIdx]);
      end;

      if FChannelShiftRate > 0 then
      begin
        for DepthCnt := 0 to ImgInput.Depth - 1 do
        begin
          LocalChannelShiftRate := ((random(10000) - 5000) / 5000);
          LocalChannelShiftRate := 1 + (LocalChannelShiftRate * FChannelShiftRate);
          ImgInput.MulAtDepth(DepthCnt, LocalChannelShiftRate);
        end;
      end;

      if (ImgInput.Depth = 3) then
      begin
        if FHasMakeGray and (Random(1000) > 750) then
        begin
          ImgInput.MakeGray(FColorEncoding);
        end;
      end;

      if FHasFlipX and (Random(1000) > 500) then
      begin
        ImgInput.FlipX();
      end;

      if FHasFlipY and (Random(1000) > 500) then
      begin
        ImgInput.FlipY();
      end;
    end
    else
    begin
      ImgInput.Copy(FImgVolumes[ImgIdx]);
    end;
    ImgInput.Tag := FImgVolumes[ImgIdx].Tag;

    if ImgInput.Tag >= FNumClasses then
    begin
      FErrorProc
      (
        'Invalid image ' + IntToStr(ImgIdx) +
        ' input class: ' + IntToStr(ImgInput.Tag)
      );
      Continue;
    end;

    LocalNN.Compute( ImgInput );
    LocalNN.GetOutput( pOutput );

    if FIsSoftmax
      then vOutput.SetClassForSoftMax( ImgInput.Tag )
      else vOutput.SetClass( ImgInput.Tag, +0.9, -0.1);

    CurrentError := vOutput.SumDiff( pOutput );
    LocalErrorSum := LocalErrorSum + CurrentError;
    OutputValue := pOutput.FData[ ImgInput.Tag ];
    if Not(FIsSoftmax) then
    begin
      OutputValue := Max(OutputValue, 0.001);
    end;

    if
      (CurrentError > FMinBackpropagationError) or
      (
        (FCurrentTrainingError>0) and
        (CurrentError > FCurrentTrainingError*FMinBackpropagationErrorProportion)
      ) then
    begin
      LocalNN.Backpropagate(vOutput);
    end
    else
    begin
      // TODO: this is an experiment to be tested:
      // decreases probability to train with good sample.
      // FTrainingSampleProcessedCnt.FData[ImgIdx] := FTrainingSampleProcessedCnt.FData[ImgIdx] + 1;
    end;

    if (OutputValue > 0) then
    begin
      CurrentLoss := -Ln(OutputValue);
    end
    else
    begin
      {$IFDEF Debug}
      //FErrorProc('Error - invalid output value at loss function:' + FloatToStrF(OutputValue,ffFixed,6,4));
      {$ENDIF}
      CurrentLoss := 100;
    end;
    LocalTotalLoss := LocalTotalLoss + CurrentLoss;

    if pOutput.GetClass() = FImgVolumes[ImgIdx].Tag then
    begin
      Inc(LocalHit);
    end
    else
    begin
      Inc(LocalMiss);
    end;
  end; // of for

  if (Index and 1 = 0) and Not(FShouldQuit) then
  begin
    if Index + 1 < FThreadNum then
    begin
      while (FFinishedThread.FData[Index + 1] = 0) and Not(FShouldQuit) do;
      LocalNN.SumDeltasNoChecks(FThreadNN[Index + 1]);
      {$IFDEF FPC}
      FFinishedThread.FData[Index] += FFinishedThread.FData[Index + 1];
      {$ELSE}
      FFinishedThread.FData[Index] := FFinishedThread.FData[Index] +
        FFinishedThread.FData[Index + 1];
      {$ENDIF}
    end;
  end;
  FFinishedThread.FData[Index] := FFinishedThread.FData[Index] + 1;
  if (Index and 3 = 0) and Not(FShouldQuit) then
  begin
    if Index + 2 < FThreadNum then
    begin
      while (FFinishedThread.FData[Index + 2] = 0) and Not(FShouldQuit) do;
      LocalNN.SumDeltasNoChecks(FThreadNN[Index + 2]);
      {$IFDEF FPC}
      FFinishedThread.FData[Index] += FFinishedThread.FData[Index + 2];
      {$ELSE}
      FFinishedThread.FData[Index] := FFinishedThread.FData[Index] +
        FFinishedThread.FData[Index + 2];
      {$ENDIF}
    end;
  end;

  {$IFDEF HASTHREADS}EnterCriticalSection(FCritSec);{$ENDIF}
  FGlobalHit       := FGlobalHit + LocalHit;
  FGlobalMiss      := FGlobalMiss + LocalMiss;
  FGlobalTotalLoss := FGlobalTotalLoss + LocalTotalLoss;
  FGlobalErrorSum  := FGlobalErrorSum + LocalErrorSum;

  FNN.ForwardTime := FNN.ForwardTime + LocalNN.ForwardTime;
  FNN.BackwardTime := FNN.BackwardTime + LocalNN.BackwardTime;
  {$IFDEF Debug}
  if Index and 3 = 0 then FNN.SumDeltas(LocalNN);
  {$ELSE}
  if Index and 3 = 0 then FNN.SumDeltasNoChecks(LocalNN);
  {$ENDIF}
  {$IFDEF HASTHREADS}LeaveCriticalSection(FCritSec);{$ENDIF}
  ImgInputCp.Free;
  ImgInput.Free;
  vOutput.Free;
  pOutput.Free;
end;

procedure TNeuralImageFit.TestNNThread(index, threadnum: integer);
var
  BlockSize: integer;
  LocalNN: TNNet;
  ImgInput, ImgInputCp: TNNetVolume;
  pOutput, vOutput, sumOutput: TNNetVolume;
  I, ImgIdx: integer;
  StartPos, FinishPos: integer;
  OutputValue, CurrentLoss: TNeuralFloat;
  LocalHit, LocalMiss: integer;
  LocalTotalLoss, LocalErrorSum: TNeuralFloat;
  PredictedClass: integer;
  TotalDiv: TNeuralFloat;
begin
  ImgInput := TNNetVolume.Create();
  ImgInputCp := TNNetVolume.Create();
  pOutput := TNNetVolume.Create(FNumClasses,1,1);
  vOutput := TNNetVolume.Create(FNumClasses,1,1);
  sumOutput := TNNetVolume.Create(FNumClasses,1,1);

  LocalHit := 0;
  LocalMiss := 0;
  LocalTotalLoss := 0;
  LocalErrorSum := 0;

  BlockSize := (FWorkingVolumes.Count div FThreadNum) {$IFDEF MakeQuick}div 10{$ENDIF};
  StartPos  := BlockSize * index;
  FinishPos := BlockSize * (index + 1) - 1;

  if index = (FThreadNum-1) then
  begin
    FinishPos := FWorkingVolumes.Count - 1;
  end;

  LocalNN := FThreadNN[Index];
  LocalNN.CopyWeights(FAvgWeight);
  LocalNN.EnableDropouts(false);
  for I := StartPos to FinishPos - 1 do
  begin
    if FShouldQuit then Break;
    sumOutput.Fill(0);
    ImgIdx := I;

    if FHasImgCrop then
    begin
      ImgInput.CopyCropping(FWorkingVolumes[ImgIdx], FMaxCropSize div 2, FMaxCropSize div 2, FImgVolumes[ImgIdx].SizeX-FMaxCropSize, FImgVolumes[ImgIdx].SizeY-FMaxCropSize);
    end
    else
    begin
      ImgInput.Copy(FWorkingVolumes[ImgIdx]);
    end;

    ImgInput.Tag := FWorkingVolumes[ImgIdx].Tag;

    LocalNN.Compute( ImgInput );
    LocalNN.GetOutput( pOutput );
    if FMultipleSamplesAtValidation then
    begin
      TotalDiv := 1;
      sumOutput.Add( pOutput );

      if FHasFlipX then
      begin
        ImgInput.FlipX();
        TotalDiv := TotalDiv + 1;
        LocalNN.Compute( ImgInput );
        LocalNN.GetOutput( pOutput );
        sumOutput.Add( pOutput );
      end;

      if FHasFlipY then
      begin
        ImgInput.FlipY();
        TotalDiv := TotalDiv + 1;
        LocalNN.Compute( ImgInput );
        LocalNN.GetOutput( pOutput );
        sumOutput.Add( pOutput );
      end;

      if ((FMaxCropSize >= 2) and Not(FHasImgCrop)) then
      begin
        ImgInputCp.CopyCropping(ImgInput, FMaxCropSize div 2, FMaxCropSize div 2, ImgInput.SizeX - FMaxCropSize, ImgInput.SizeY - FMaxCropSize);
        ImgInput.CopyResizing(ImgInputCp, ImgInput.SizeX, ImgInput.SizeY);
        LocalNN.Compute( ImgInput );
        LocalNN.GetOutput( pOutput );
        sumOutput.Add( pOutput );
        TotalDiv := TotalDiv + 1;
      end;
      sumOutput.Divi(TotalDiv);

      pOutput.Copy(sumOutput);
    end;

    vOutput.SetClassForSoftMax( ImgInput.Tag );
    LocalErrorSum := LocalErrorSum + vOutput.SumDiff( pOutput );

    OutputValue := pOutput.FData[ ImgInput.Tag ];
    if Not(FIsSoftmax) then OutputValue := OutputValue + 0.5001;

    if (OutputValue > 0) then
    begin
      CurrentLoss := -Ln(OutputValue);
    end
    else
    begin
      {$IFDEF Debug}
      //FErrorProc('Error - invalid output value at loss function:' + FloatToStrF(OutputValue,ffFixed,6,4));
      {$ENDIF}
      CurrentLoss := 100;
    end;
    LocalTotalLoss := LocalTotalLoss + CurrentLoss;

    PredictedClass := pOutput.GetClass();
    if PredictedClass = ImgInput.Tag then
    begin
      Inc(LocalHit);
    end
    else
    begin
      Inc(LocalMiss);
    end;
  end; // of for
  LocalNN.EnableDropouts(true);

  {$IFDEF HASTHREADS}EnterCriticalSection(FCritSec);{$ENDIF}
  FGlobalHit       := FGlobalHit + LocalHit;
  FGlobalMiss      := FGlobalMiss + LocalMiss;
  FGlobalTotalLoss := FGlobalTotalLoss + LocalTotalLoss;
  FGlobalErrorSum  := FGlobalErrorSum + LocalErrorSum;
  {$IFDEF HASTHREADS}LeaveCriticalSection(FCritSec);{$ENDIF}

  sumOutput.Free;
  ImgInputCp.Free;
  ImgInput.Free;
  vOutput.Free;
  pOutput.Free;
end;

procedure TNeuralFitWithImageBase.ClassifyImage(pNN: TNNet; pImgInput, pOutput: TNNetVolume);
var
  ImgInput, ImgInputCp: TNNetVolume;
  sumOutput: TNNetVolume;
  TotalDiv: TNeuralFloat;
begin
  ImgInput := TNNetVolume.Create();
  ImgInputCp := TNNetVolume.Create();
  sumOutput := TNNetVolume.Create(pNN.GetLastLayer().Output);

  ImgInput.Copy( pImgInput );
  pNN.Compute( ImgInput );
  pNN.GetOutput( pOutput );

  if FMultipleSamplesAtValidation then
  begin
    TotalDiv := 1;
    sumOutput.Add( pOutput );

    if FHasFlipX then
    begin
      ImgInput.FlipX();
      TotalDiv := TotalDiv + 1;
      pNN.Compute( ImgInput );
      pNN.GetOutput( pOutput );
      sumOutput.Add( pOutput );
    end;

    if FHasFlipY then
    begin
      ImgInput.FlipY();
      TotalDiv := TotalDiv + 1;
      pNN.Compute( ImgInput );
      pNN.GetOutput( pOutput );
      sumOutput.Add( pOutput );
      ImgInput.FlipY();
    end;

    if FMaxCropSize >= 2 then
    begin
      ImgInputCp.CopyCropping(ImgInput, FMaxCropSize div 2, FMaxCropSize div 2, ImgInput.SizeX - FMaxCropSize, ImgInput.SizeY - FMaxCropSize);
      ImgInput.CopyResizing(ImgInputCp, ImgInput.SizeX, ImgInput.SizeY);
      pNN.Compute( ImgInput );
      pNN.GetOutput( pOutput );
      sumOutput.Add( pOutput );
      TotalDiv := TotalDiv + 1;
    end;
    sumOutput.Divi(TotalDiv);

    pOutput.Copy(sumOutput);
  end;

  sumOutput.Free;
  ImgInputCp.Free;
  ImgInput.Free;
end;

procedure TNeuralFitWithImageBase.ClassifyImageFromFile(pNN: TNNet;
  pFilename: string; pOutput: TNNetVolume);
var
  vInputImage: TNNetVolume;
  InputSizeX, InputSizeY, NumberOfClasses: integer;
begin
  vInputImage := TNNetVolume.Create();
  InputSizeX := pNN.Layers[0].Output.SizeX;
  InputSizeY := pNN.Layers[0].Output.SizeY;
  NumberOfClasses := pNN.GetLastLayer().Output.Size;
  if pOutput.Size <> NumberOfClasses then pOutput.ReSize(pNN.GetLastLayer().Output);
  pOutput.Fill(0);
  if LoadImageFromFileIntoVolume(
      pFilename, vInputImage, InputSizeX, InputSizeY,
      {EncodeNeuronalInput=}csEncodeRGB) then
  begin
    ClassifyImage(pNN, vInputImage, pOutput);
  end;
  vInputImage.Free;
end;

function TNeuralFitWithImageBase.ClassifyImageFromFile(pNN: TNNet;
  pFilename: string): integer;
var
  vOutput: TNNetVolume;
begin
  vOutput := TNNetVolume.Create();
  ClassifyImageFromFile(pNN, pFilename, vOutput);
  Result := vOutput.GetClass();
  vOutput.Free;
end;

procedure TNeuralFitWithImageBase.EnableDefaultImageTreatment();
begin
  FColorEncoding := 0;
  FHasImgCrop := false;
  FHasResizing := True;
  FHasFlipX := True;
  FHasFlipY := false;
  FHasMakeGray := True;
  FMaxCropSize := 8;
  FMinBackpropagationError := 0.2;
  FMinBackpropagationErrorProportion := 0.25;
  FMultipleSamplesAtValidation := True;
end;

end.
