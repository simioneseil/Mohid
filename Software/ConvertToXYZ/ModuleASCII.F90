!------------------------------------------------------------------------------
!        IST/MARETEC, Water Modelling Group, Mohid modelling system
!------------------------------------------------------------------------------
!
! TITLE         : Mohid Model
! PROJECT       : Mohid Base 1
! MODULE        : ASCII
! URL           : http://www.mohid.com
! AFFILIATION   : IST/MARETEC, Marine Modelling Group
! DATE          : September 2004
! REVISION      : Rosa Trancoso
! DESCRIPTION   : Module to convert ArcView ASCII file into XYZ format within a defined window.
!                 
!------------------------------------------------------------------------------



!   INPUT_FILENAME              : char              -           !Path to input file to convert
!   OUTPUT_FILENAME             : char              -           !Path to XYZ file generated
!   REDUCE_RESOLUTION           : 0/1               0           !Connect/Disconnect resolution reduction
!   REDUCE_RESOLUTION_STEP      : integer           0           !Interval of points that will be picked


Module ModuleASCII

    use ModuleGlobalData
    use ModuleDrawing
    use ModuleEnterData

    implicit none

    private 

    !Subroutines---------------------------------------------------------------

    !Constructor
    public  :: ConvertASCII
    private ::      ReadOptions
    private ::      OpenFile
    private ::      ReadASCIIWindow
    private ::      KillASCII

    !Parameters----------------------------------------------------------------
    integer, parameter                  :: iLongitude   = 10800
    integer, parameter                  :: iLatitude    = 5400   

    !Types---------------------------------------------------------------------
    type      T_ASCII
        integer                         :: Unit
        integer                         :: OutputUnit
        type(T_Limits)                  :: Window
        character(len=StringLength)     :: FileName
        character(len=StringLength)     :: OutputFileName
        logical                         :: IgnoreNegativeValues
        logical                         :: ReduceResolution
        integer                         :: ReduceResolutionStep
        integer                         :: nCols
        integer                         :: nRows
        real                            :: xllCorner
        real                            :: yllCorner
        real                            :: CellSize
        real                            :: NoDataValue
        real                            :: AddFactor
        real                            :: MultiplyFactor
        logical                         :: ChangeZ
        real, dimension(:), pointer     :: Z
        integer                         :: ObjEnterData = 0
    end type  T_ASCII

    type(T_ASCII), pointer             :: Me

    !--------------------------------------------------------------------------
    
    contains


    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    !CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONSTRUCTOR CONS

    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    !++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

    subroutine ConvertASCII(Window, EnterDataID, STAT)

        !Arguments---------------------------------------------------------------
        type(T_Limits),    intent(IN )                  :: Window
        integer,           intent(IN )                  :: EnterDataID
        integer, optional, intent(OUT)                  :: STAT

        !------------------------------------------------------------------------

        STAT = UNKNOWN_

        nullify (Me)
        allocate(Me)

        Me%Window               = Window
        Me%ObjEnterData         = AssociateInstance(mEnterData_, EnterDataID)

        call ReadOptions

        call OpenFile

        call ReadASCIIWindow

        call ReadFileAndWriteOutput

        call KillASCII

        STAT = SUCCESS_

    end subroutine ConvertASCII


    !--------------------------------------------------------------------------

    subroutine ReadOptions

        !Local-----------------------------------------------------------------
        integer                 :: iflag, STAT_CALL

        !Begin---------------------------------------------------------

        call GetData(Me%FileName,                                   &
                     Me%ObjEnterData, iflag,                        &
                     SearchType   = FromBlock,                      &
                     keyword      = 'INPUT_FILENAME',               &
                     ClientModule = 'ModuleASCII',                  &
                     STAT         = STAT_CALL)        
        if (STAT_CALL /= SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR010'

        if (iflag == 0)then
            write(*,*)'Must specify name of file to convert'
            stop 'ReadOptions - ModuleASCII - ERR60'
        end if

        call GetData(Me%OutputFileName,                             &
                     Me%ObjEnterData, iflag,                        &
                     SearchType   = FromBlock,                      &
                     keyword      = 'OUTPUT_FILENAME',              &
                     ClientModule = 'ModuleASCII',                  &
                     STAT         = STAT_CALL)        
        if (STAT_CALL /= SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR020'

        call GetData(Me%IgnoreNegativeValues,                       &
                     Me%ObjEnterData, iflag,                        &
                     SearchType   = FromBlock,                      &
                     keyword      = 'IGNORE_NEGATIVE_VALUES',       &
                     default      = .false.,                        &
                     ClientModule = 'ModuleASCII',                  &
                     STAT         = STAT_CALL)        
        if (STAT_CALL /= SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR030'
        
        !Reduce resolution (ignore points at specific interval). This can be quite usefull when 
        !handling very detailed DTM's that can not be opened in GUI because of the size. It can be 
        !usefull to inspect data and compare to result grid data DTM from Digital Terrain Creator
        call GetData(Me%ReduceResolution,                           &
                     Me%ObjEnterData, iflag,                        &
                     SearchType   = FromBlock,                      &
                     keyword      = 'REDUCE_RESOLUTION',            &
                     default      = .false.,                        &
                     ClientModule = 'ModuleASCII',                  &
                     STAT         = STAT_CALL)        
        if (STAT_CALL /= SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR040'
        
        !what will be the frequency of points to pick
        if (Me%ReduceResolution) then
            call GetData(Me%ReduceResolutionStep,                       &
                         Me%ObjEnterData, iflag,                        &
                         SearchType   = FromBlock,                      &
                         keyword      = 'REDUCE_RESOLUTION_STEP',       &
                         default      = 0,                              &
                         ClientModule = 'ModuleASCII',                  &
                         STAT         = STAT_CALL)        
            if (STAT_CALL /= SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR040'
        endif

        call GetData(Me%AddFactor,                                                      &
                     Me%ObjEnterData, iflag,                                            &
                     SearchType   = FromFile_,                                          &
                     keyword      ='ADD_FACTOR',                                        &
                     ClientModule ='DigitalTerrainCreator',                             &
                     Default      = 0.,                                                 &
                     STAT         = STAT_CALL)        
        if(STAT_CALL .ne. SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR060'

        call GetData(Me%MultiplyFactor,                                                 &
                     Me%ObjEnterData, iflag,                                            &
                     SearchType   = FromFile_,                                          &
                     keyword      ='MULTIPLY_FACTOR',                                   &
                     ClientModule ='DigitalTerrainCreator',                             &
                     Default      = 1.,                                                 &
                     STAT         = STAT_CALL)        
        if(STAT_CALL .ne. SUCCESS_) stop 'ReadOptions - ModuleASCII - ERR070'
        
        Me%ChangeZ = .false.
        if ((Me%AddFactor .ne. 0.) .or. (Me%MultiplyFactor .ne. 1.)) then
            Me%ChangeZ = .true.
        endif
        
        
    end subroutine ReadOptions


    
    !--------------------------------------------------------------------------

    
    subroutine OpenFile

        !Local-----------------------------------------------------------------
        integer                                     :: STAT_CALL
        logical                                     :: exist

        !Begin---------------------------------------------------------


        !Verifies if file exists
        inquire(file = Me%FileName, exist = exist)
        if (.not. exist) then
            write(*,*)'ASCII file does not exist'
            stop 'OpenFile - ModuleASCII - ERR01'
        endif

        call UnitsManager(Me%Unit, OPEN_FILE, STAT = STAT_CALL) 
        if (STAT_CALL /= SUCCESS_) stop 'OpenFile - ModuleASCII - ERR02'

        open(Unit   = Me%Unit,              &
             File   = Me%FileName,          &
             STATUS = 'OLD',                &
             Action = 'READ',               &
             IOSTAT = STAT_CALL) 
        if (STAT_CALL /= SUCCESS_) stop 'OpenFile - ModuleASCII - ERR03'

        rewind(Me%Unit)

        write(*,*)
        write(*,*)"Opened ASCII file..."


    end subroutine OpenFile

    !--------------------------------------------------------------------------

    
    subroutine ReadASCIIWindow

        !Local------------------------------------------------------------------
        character (StringLength)                    :: aux_string

        !Begin------------------------------------------------------------------


        write(*,*)
        write(*,*)"Preparing to read..."


        read(Me%Unit,*) aux_string, Me%nCols
        read(Me%Unit,*) aux_string, Me%nRows
        read(Me%Unit,*) aux_string, Me%xllCorner
        read(Me%Unit,*) aux_string, Me%yllCorner
        read(Me%Unit,*) aux_string, Me%CellSize
        read(Me%Unit,*) aux_string, Me%NoDataValue

        allocate(Me%Z (1:Me%nCols))
        Me%Z = null_real


    end subroutine ReadASCIIWindow
        
    !---------------------------------------------------------------------------

    subroutine ReadFileAndWriteOutput


        !Local------------------------------------------------------------------
        real                                        :: X,Y, Z
        integer                                     :: i,j
        integer                                     :: STAT_CALL
        integer                                     :: Counter                 !for reducing resolution case

        !Begin------------------------------------------------------------------

        call UnitsManager(Me%OutputUnit, OPEN_FILE, STAT = STAT_CALL) 
        if (STAT_CALL /= SUCCESS_) stop 'ReadFileAndWriteOutput - ModuleASCII - ERR02'

        open(Unit   = Me%OutputUnit,                &
             File   = Me%OutputFileName,            &
             STATUS = 'UNKNOWN',                    &
             IOSTAT = STAT_CALL) 
        if (STAT_CALL /= SUCCESS_) stop 'ReadFileAndWriteOutput - ModuleASCII - ERR03'

        write(*,*)
        write(*,*)"Writing XYZ file. Please wait..."

        write(Me%OutputUnit,*)"<begin_xyz>"        
        
        !O arcview comeca a escrever os valores z do LeftUpperCorner
        !Depois escreve uma row e vai descendo nos YYs
        !considerei que xllcorner e yllcorner eram do centro da celula

        X = Me%xllCorner + Me%CellSize/2
        Y = Me%yllCorner + Me%nRows * Me%CellSize - Me%CellSize/2
        
        !if reducing resolution, initialize counter so that first point is written
        Counter = Me%ReduceResolutionStep
        
        do i = 1, Me%nRows
        
            read (Me%Unit, *) (Me%Z(j), j = 1, Me%nCols)

            do j = 1, Me%nCols
                if ((.not. Me%IgnoreNegativeValues) .or. (Me%Z(j) >= 0.)) then
                    Counter = Counter + 1
                    if ((.not. Me%ReduceResolution) .or. (Counter >= Me%ReduceResolutionStep)) then
                        if (Me%ChangeZ) then
                            Z = Me%Z(j) * Me%MultiplyFactor + Me%AddFactor
                            write(Me%OutputUnit,*) X, Y, Z
                        else
                            write(Me%OutputUnit,*) X, Y, Me%Z(j)
                        endif
                        Counter = 0
                    endif
                endif
                X = X + Me%CellSize               
            end do
            
            Y = Y - Me%CellSize
            X = Me%xllCorner + Me%CellSize/2

        end do

        write(Me%OutputUnit,*)"<end_xyz>"
        
        write(*,*)
        write(*,*)"Finished writing..."


    end subroutine ReadFileAndWriteOutput
    
    
    subroutine KillASCII
        
        !Local-----------------------------------------------------------------
        integer                     :: STAT_CALL, nUsers
        
        !Begin-----------------------------------------------------------------

        !deallocate (Me%Z)

        call UnitsManager(Me%Unit, CLOSE_FILE, STAT = STAT_CALL) 
        if (STAT_CALL /= SUCCESS_) stop 'KillASCII - ModuleASCII - ERR01'

        call UnitsManager(Me%OutputUnit, CLOSE_FILE, STAT = STAT_CALL) 
        if (STAT_CALL /= SUCCESS_) stop 'KillASCII - ModuleASCII - ERR02'

        nUsers = DeassociateInstance(mENTERDATA_, Me%ObjEnterData)
        if (nUsers == 0)           stop 'KillASCII - ModuleASCII - ERR03'

        deallocate(Me)
        nullify   (Me)

    
    end subroutine KillASCII

    !--------------------------------------------------------------------------

 
end module ModuleASCII









