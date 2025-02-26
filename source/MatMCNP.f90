!
!  Copyright (c) 2019 National Technology & Engineering Solutions of
!  Sandia, LLC (NTESS). Under the terms of Contract DE-NA0003525 with
!  NTESS, the U.S. Government retains certain rights in this software.
!
!****************************************************************************
!
!  PROGRAM: MatMCNP
!
!  PURPOSE:  This program calculates the material cards for MCNP/MCNPX input
!            decks.  The atomic and weight fractions are calculated for each
!            isotope in the material regardless of whether or not the cross
!            section data exists at the isotopic level for the elements in
!            the material.  In addition to the material computation, the
!            FM card for converting neutron and gamma fluences to dose in
!            the material is also generated.
!
!  Version Notes:
!   Version 4.0
!   - First open source code release
!   Version 4.1
!    - NWC Data updated to "Nuclear Wallet Cards database version of 7/10/2019"
!    - Default zaids for material cards become ENDF/B-VIII.0 at 293.6 K (*.00c)
!    - New xsec evaluations for O-18, Neon, Ytterbium, Osmium, and Platinum.
!    - Carbon must now be treated isotopically rather than as an element.
!    - The "naturalzaid" routine is no longer is used. It is left as a "CONTINUE"
!        statement in the Fortran, but it isn't called.
!    - Command line arguments for input/output file are now allowed.
!
!   XGEN Version
!    - Added an option to produce an input file for xgen.
!    - If the material number is set to xgen, the input file (matxgen.inp)
!       will be generated.
!    - The default energy for xgen is 1.00 MeV
!    - A new subroutine (assign_z_to_element) was created at the bottom of 
!       this file - it may be moved in the future.
!    - No new calculations are performed. This is simply a new format to 
!       output results of the material calculation.
!
!****************************************************************************
!
PROGRAM MatMCNP
   USE NWC_2000
   USE NWC_DATABASE
   IMPLICIT NONE

   !Variables
   CHARACTER(LEN=80)::infile,outfile,xgenfile,comment_line
   CHARACTER(LEN=67)::xgen_title

   REAL:: compound_density,total_atom_b_cm,total_fake_atomic_weight,FM_value
   REAL, DIMENSION(92):: a_or_w_percent, w_percent,a_percent, fake_atomic_weight
   REAL,DIMENSION(300):: iso_atom_b_cm
   INTEGER:: num_args,number_elements,i,out_flag
   INTEGER, DIMENSION(92)::z_of_element
   CHARACTER(LEN=3), DIMENSION(92)::natural_or_enriched
   CHARACTER(LEN=6):: atomic, weight,symbol,atom_or_weight
   CHARACTER(LEN=5)::mat_number
   CHARACTER(LEN=2)::xgen_z
	
   !Call to subroutine with the elements and their nuclear card information
   !in groups of five.
   CALL Z1_Z5
   CALL Z6_Z10
   CALL Z11_Z15
   CALL Z16_Z20
   CALL Z21_Z25
   CALL Z26_Z30
   CALL Z31_Z35
   CALL Z36_Z40
   CALL Z41_Z45
   CALL Z46_Z50
   CALL Z51_Z55
   CALL Z56_Z60
   CALL Z61_Z65
   CALL Z66_Z70
   CALL Z71_Z75
   CALL Z76_Z80
   CALL Z81_Z85
   CALL Z86_Z90
   CALL Z91_Z92

   !Assign names to input and output file.
   !
   num_args = COMMAND_ARGUMENT_COUNT()
   IF (num_args == 0) THEN
     ! The old method of input and output.
     infile = "matmcnp.inp"
     outfile = "matmcnp.out"
     xgenfile = "matxgen.inp"
   ELSE IF (num_args == 2) THEN
     ! Accept input as argument #1 and output as argument #2
     ! Not checking for it, but this will fail for filenames > 80 characters.
     CALL GET_COMMAND_ARGUMENT(1, infile)
     infile = TRIM(infile)
     CALL GET_COMMAND_ARGUMENT(2, outfile)
     outfile = TRIM(outfile)
     xgenfile = "matxgen.inp"
   ELSE IF (num_args == 3) THEN
     ! Accept input as argument #1, output as argument #2, xgen input as argument #3
     ! Not checking for it, but this will fail for filenames > 80 characters.
     CALL GET_COMMAND_ARGUMENT(1, infile)
     infile = TRIM(infile)
     CALL GET_COMMAND_ARGUMENT(2, outfile)
     outfile = TRIM(outfile)
     CALL GET_COMMAND_ARGUMENT(3, xgenfile)
     xgenfile = TRIM(xgenfile)
   ELSE
     PRINT*, "MatMCNP expects no arguments, 2 arguments, or 3 arguments."
     PRINT*, ""
     PRINT*, " If no argument is used, matmcnp.inp is the input file,"
     PRINT*, "   matmcnp.out is the output file, and matxgen.inp is "
     PRINT*, "   the input for xgen."
     PRINT*, ""
     PRINT*, " If 2 arguments are used, the input filename is the 1st argument"
     PRINT*, "   and the output filename is the 2nd argument. The xgen input "
     PRINT*, "   is called matxgen.inp"
     PRINT*, ""
     PRINT*, " If 3 arguments are used, the input filename is the 1st argument,"
     PRINT*, "   the output filename is the 2nd argument, the xgen input is the"
     PRINT*, "   3rd argument."
     STOP
   END IF

   ! Open the input and output file.
   OPEN (UNIT = 10, FILE = infile, STATUS = "OLD")
   OPEN (UNIT = 11, FILE = outfile, STATUS = "UNKNOWN")
   
   !Read the title of the mixture and the comment cards from the input.
   CALL title_comment
   
   !Read the density, whether the fractions are atomic or weight, the number of elements,
   !the z of each element, whether each element is natural or enriched, the atomic (or weight)
   !fraction, and the MCNP material number.
   CALL read_data(compound_density,atom_or_weight,number_elements,z_of_element, &
                  natural_or_enriched,a_or_w_percent,mat_number,out_flag)

   ! Close the input file.
   CLOSE(10)

   !IF statement for atomic or weight percent
   IF (atom_or_weight == 'atomic') THEN

     a_percent = a_or_w_percent

     !Calculate the weight percent.
     CALL weight_percent(w_percent,z_of_element,number_elements,a_or_w_percent)

     !Calculate the atom density of each isotope and the total.
     CALL atom_density(w_percent,compound_density,z_of_element,total_atom_b_cm,&
                       number_elements,iso_atom_b_cm)

     iso_atom_b_cm = iso_atom_b_cm/100

   ELSE IF (atom_or_weight == 'weight') THEN
   
     w_percent = a_or_w_percent
     !Calculate the atom density of each isotope and the total density.
     CALL atom_density(w_percent,compound_density,z_of_element,total_atom_b_cm,&
                       number_elements,iso_atom_b_cm)

     iso_atom_b_cm = iso_atom_b_cm/100

   ELSE
     !Error message if user does not specify "atomic" or "weight" in the input file.
     WRITE (UNIT=11,FMT=104) 
     STOP
   END IF

   DO i=1, num_iso
     !
     !Calculate each isotope's atom fraction (at this point, iso_atom_b_cm 
     !and total_atom_b_cm have already been divided by 100).
     !
     output_array(i)%atom_percent = iso_atom_b_cm(i)/total_atom_b_cm
     !
     !Divide weight percent of each isotope by 100 to get the weight fraction.
     !
     output_array(i)%weight_percent = output_array(i)%weight_percent/100

   END DO

   !Initialize the "atomic weight" to be used for calculating the FM card
   total_fake_atomic_weight = 0.0

   !FM card.  The formula used here can be found on page 3-97 of the MCNP5
   ! User's Manual.
   DO i=1,num_iso
       fake_atomic_weight = output_array(i)%atom_percent * output_array(i)%isotopic_mass
       total_fake_atomic_weight = total_fake_atomic_weight + fake_atomic_weight(i)
   END DO

   FM_value = (((6.02214129E23 * 1E-24)/total_fake_atomic_weight) * 1.602E-8)

   !Print all of the data to the output file.
   CALL print_data(total_atom_b_cm,iso_atom_b_cm,mat_number,z_of_element)
   WRITE(UNIT=11,FMT=105)
   WRITE(UNIT=11,FMT=106)   FM_value, mat_number
   WRITE(UNIT=11,FMT=107)   FM_value, mat_number
   CLOSE(11)
   
   IF (out_flag == 1) THEN
      OPEN (UNIT = 11, FILE = outfile, STATUS = "OLD")
      OPEN (UNIT = 12, FILE =xgenfile, STATUS= "UNKNOWN")
      WRITE(UNIT=12, FMT=1000)
      READ(UNIT=11,FMT=1001) xgen_title  !This is a comment - chunk it.
      READ(UNIT=11,FMT=1001) xgen_title  !This is what we are looking for.
      WRITE(UNIT=12,FMT=1002) xgen_title
      WRITE(UNIT=12,FMT=1003)
      DO
         READ(UNIT=11,FMT=1004) comment_line
         IF (comment_line(1:1) == 'C') THEN
             WRITE(UNIT=12,FMT=1005) comment_line(2:80)
         ELSE
             EXIT
         END IF
      END DO
      WRITE(UNIT=12,FMT=1006)
      DO i=1, number_elements
          CALL assign_z_to_element(z_of_element(i), xgen_z)
          IF (i < number_elements) THEN
	     WRITE(UNIT=12,FMT=1007) xgen_z, w_percent(i)
          ELSE
	     WRITE(UNIT=12,FMT=1009) xgen_z, w_percent(i)
          END IF
      END DO
      WRITE(UNIT=12,FMT=1008) compound_density
      CLOSE(11)
      CLOSE(12)
   END IF
      
   

   !Format Statement
   104 FORMAT (/"Error: Need to specify whether atomic or weight percent.")
   105 FORMAT ("C"/"C",2X,"To convert a particle flux to rad[Material]")
   106 FORMAT ("C",2X,"use FM ",ES14.7," ",A5,"-4  1 for neutrons")
   107 FORMAT ("C",2X," or FM ",ES14.7," ",A5,"-5 -6 for photons."/"C")
  1000 FORMAT ("TITLE")
  1001 FORMAT (2X,A)
  1002 FORMAT ("...",A65)
  1003 FORMAT ("energy 1.00")
  1004 FORMAT (A)
  1005 FORMAT ('* ', A79)
  1006 FORMAT ("MATERIAL -")
  1007 FORMAT (2x,A2,2x,F10.7, " -")
  1008 FORMAT ("DENSITY",2x,F11.7)
  1009 FORMAT (2x,A2,2x,F10.7)
      
   

   !Format Statement
   104 FORMAT (/"Error: Need to specify whether atomic or weight percent.")
   105 FORMAT ("C"/"C",2X,"To convert a particle flux to rad[Material]")
   106 FORMAT ("C",2X,"use FM ",ES14.7," ",A5,"-4  1 for neutrons")
   107 FORMAT ("C",2X," or FM ",ES14.7," ",A5,"-5 -6 for photons."/"C")
  1000 FORMAT ("TITLE")
  1001 FORMAT (2X,A)
  1002 FORMAT ("...",A65)
  1003 FORMAT ("energy 1.00")
  1004 FORMAT (A)
  1005 FORMAT ('* ', A79)
  1006 FORMAT ("MATERIAL")
  1007 FORMAT (2x,A2,2x,F10.7)
  1008 FORMAT ("DENSITY",2x,F11.7)

END PROGRAM MatMCNP


!!!!!!
   SUBROUTINE assign_z_to_element(in_z,out_z)
     IMPLICIT NONE
     
     INTEGER,INTENT(IN)::in_z
     CHARACTER(LEN=2),INTENT(OUT)::out_z
     
     SELECT CASE (in_z)

     CASE(1)
       out_z = 'H '
     CASE(2)
       out_z = 'He'
     CASE(3)
       out_z = 'Li'
     CASE(4)
       out_z = 'Be'
     CASE(5)
       out_z = 'B '
     CASE(6)
       out_z = 'C '
     CASE(7)
       out_z = 'N '
     CASE(8)
       out_z = 'O '
     CASE(9)
       out_z = 'F '
     CASE(10)
       out_z = 'Ne'
     CASE(11)
       out_z = 'Na'
     CASE(12)
       out_z = 'Mg'
     CASE(13)
       out_z = 'Al'
     CASE(14)
       out_z = 'Si'
     CASE(15)
       out_z = 'P '
     CASE(16)
       out_z = 'S '
     CASE(17)
       out_z = 'Cl'
     CASE(18)
       out_z = 'Ar'
     CASE(19)
       out_z = 'K '
     CASE(20)
       out_z = 'Ca'
     CASE(21)
       out_z = 'Sc'
     CASE(22)
       out_z = 'Ti'
     CASE(23)
       out_z = 'V '
     CASE(24)
       out_z = 'Cr'
     CASE(25)
       out_z = 'Mn'
     CASE(26)
       out_z = 'Fe'
     CASE(27)
       out_z = 'Co'
     CASE(28)
       out_z = 'Ni'
     CASE(29)
       out_z = 'Cu'
     CASE(30)
       out_z = 'Zn'
     CASE(31)
       out_z = 'Ga'
     CASE(32)
       out_z = 'Ge'
     CASE(33)
       out_z = 'As'
     CASE(34)
       out_z = 'Se'
     CASE(35)
       out_z = 'Br'
     CASE(36)
       out_z = 'Kr'
     CASE(37)
       out_z = 'Rb'
     CASE(38)
       out_z = 'Sr'
     CASE(39)
       out_z = 'Y '
     CASE(40)
       out_z = 'Zr'
     CASE(41)
       out_z = 'Nb'
     CASE(42)
       out_z = 'Mo'
     CASE(44)
       out_z = 'Ru'
     CASE(45)
       out_z = 'Rh'
     CASE(46)
       out_z = 'Pd'
     CASE(47)
       out_z = 'Ag'
     CASE(48)
       out_z = 'Cd'
     CASE(49)
       out_z = 'In'
     CASE(50)
       out_z = 'Sn'
     CASE(51)
       out_z = 'Sb'
     CASE(52)
       out_z = 'Te'
     CASE(53)
       out_z = 'I '
     CASE(54)
       out_z = 'Xe'
     CASE(55)
       out_z = 'Cs'
     CASE(56)
       out_z = 'Ba'
     CASE(57)
       out_z = 'La'
     CASE(58)
       out_z = 'Ce'
     CASE(59)
       out_z = 'Pr'
     CASE(60)
       out_z = 'Nd'
     CASE(62)
       out_z = 'Sm'
     CASE(63)
       out_z = 'Eu'
     CASE(64)
       out_z = 'Gd'
     CASE(65)
       out_z = 'Tb'
     CASE(66)
       out_z = 'Dy'
     CASE(67)
       out_z = 'Ho'
     CASE(68)
       out_z = 'Er'
     CASE(69)
       out_z = 'Tm'
     CASE(70)
       out_z = 'Yb'
     CASE(71)
       out_z = 'Lu'
     CASE(72)
       out_z = 'Hf'
     CASE(73)
       out_z = 'Ta'
     CASE(74)
       out_z = 'W '
     CASE(75)
       out_z = 'Re'
     CASE(76)
       out_z = 'Os'
     CASE(77)
       out_z = 'Ir'
     CASE(78)
       out_z = 'Pt'
     CASE(79)
       out_z = 'Au'
     CASE(80)
       out_z = 'Hg'
     CASE(81)
       out_z = 'Tl'
     CASE(82)
       out_z = 'Pb'
     CASE(83)
       out_z = 'Bi'
     CASE(90)
       out_z = 'Th'
     CASE(92)
       out_z = 'U '

     END SELECT
     
   END SUBROUTINE assign_z_to_element
