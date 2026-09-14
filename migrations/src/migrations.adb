with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Text_IO;

procedure Migrations is
   use Ada.Command_Line;
   use Ada.Text_IO;

   type Edition is (Rust_2015, Rust_2018, Rust_2021, Rust_2024);

   function Parse_Edition (Value : String) return Edition is
   begin
      if Value = "2015" then
         return Rust_2015;
      elsif Value = "2018" then
         return Rust_2018;
      elsif Value = "2021" then
         return Rust_2021;
      elsif Value = "2024" then
         return Rust_2024;
      else
         raise Constraint_Error with
           "unsupported Rust edition '" & Value & "' (use 2015, 2018, 2021, or 2024)";
      end if;
   end Parse_Edition;

   function Image (Value : Edition) return String is
   begin
      case Value is
         when Rust_2015 => return "2015";
         when Rust_2018 => return "2018";
         when Rust_2021 => return "2021";
         when Rust_2024 => return "2024";
      end case;
   end Image;

   function Guide_URL (Value : Edition) return String is
   begin
      case Value is
         when Rust_2015 => return "https://doc.rust-lang.org/edition-guide/rust-2015.html";
         when Rust_2018 => return "https://doc.rust-lang.org/edition-guide/rust-2018.html";
         when Rust_2021 => return "https://doc.rust-lang.org/edition-guide/rust-2021.html";
         when Rust_2024 => return "https://doc.rust-lang.org/edition-guide/rust-2024.html";
      end case;
   end Guide_URL;

   function Manifest_For (Path : String) return String is
      Candidate : constant String :=
        (if Ada.Directories.Simple_Name (Path) = "Cargo.toml"
           or else Ada.Directories.Extension (Path) = "toml"
         then Path
         else Ada.Directories.Compose (Path, "Cargo.toml"));
   begin
      if not Ada.Directories.Exists (Candidate) then
         raise Name_Error with "Cargo.toml not found at " & Candidate;
      end if;
      return Candidate;
   end Manifest_For;

   procedure Read_Edition
     (Manifest : String;
      Found : out Boolean;
      Current : out Edition) is
      File : File_Type;
      Line : String (1 .. 4096);
      Last : Natural;
      Key : Natural;
      Opening : Natural;
      Closing : Natural;
   begin
      Found := False;
      Current := Rust_2015;
      Open (File, In_File, Manifest);
      while not End_Of_File (File) loop
         Get_Line (File, Line, Last);
         if Last > 0 then
            Key := Ada.Strings.Fixed.Index (Line (1 .. Last), "edition");
            Opening := 0;
            Closing := 0;
            if Key > 0 then
               for Position in Key .. Last loop
                  if Line (Position) = '"' then
                     Opening := Position;
                     exit;
                  end if;
               end loop;
            end if;
            if Opening > 0 then
               for Position in Opening + 1 .. Last loop
                  if Line (Position) = '"' then
                     Closing := Position;
                     exit;
                  end if;
               end loop;
            end if;
            if Closing > Opening then
               Current := Parse_Edition (Line (Opening + 1 .. Closing - 1));
               Found := True;
               exit;
            end if;
         end if;
      end loop;
      Close (File);
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         raise;
   end Read_Edition;

   procedure Migrate_Manifest
     (Manifest : String;
      Target : Edition;
      Dry_Run : Boolean) is
      Input_File : File_Type;
      Output_File : File_Type;
      Line : String (1 .. 4096);
      Last : Natural;
      Key : Natural;
      Opening : Natural;
      Closing : Natural;
      Temporary : constant String := Manifest & ".migrations.tmp";
      Replaced : Boolean := False;
   begin
      if Dry_Run then
         Put_Line ("Preview: would update " & Manifest & " to edition " & Image (Target));
         Put_Line ("Guide:   " & Guide_URL (Target));
         return;
      end if;
      Open (Input_File, In_File, Manifest);
      Create (Output_File, Out_File, Temporary);
      while not End_Of_File (Input_File) loop
         Get_Line (Input_File, Line, Last);
         Key := 0;
         Opening := 0;
         Closing := 0;
         if Last > 0 then
            Key := Ada.Strings.Fixed.Index (Line (1 .. Last), "edition");
            if Key > 0 then
               for Position in Key .. Last loop
                  if Line (Position) = '"' then
                     Opening := Position;
                     exit;
                  end if;
               end loop;
            end if;
            if Opening > 0 then
               for Position in Opening + 1 .. Last loop
                  if Line (Position) = '"' then
                     Closing := Position;
                     exit;
                  end if;
               end loop;
            end if;
         end if;
         if (not Replaced) and then Closing > Opening then
            Put (Output_File, Line (1 .. Opening));
            Put (Output_File, Image (Target));
            Put_Line (Output_File, Line (Closing .. Last));
            Replaced := True;
         elsif Last > 0 then
            Put_Line (Output_File, Line (1 .. Last));
         else
            New_Line (Output_File);
         end if;
      end loop;
      Close (Input_File);
      Close (Output_File);
      Ada.Directories.Delete_File (Manifest);
      Ada.Directories.Rename (Temporary, Manifest);
      Put_Line ("Updated: " & Manifest & " to edition " & Image (Target));
      Put_Line ("Guide:   " & Guide_URL (Target));
   exception
      when others =>
         if Is_Open (Input_File) then
            Close (Input_File);
         end if;
         if Is_Open (Output_File) then
            Close (Output_File);
         end if;
         if Ada.Directories.Exists (Temporary) then
            Ada.Directories.Delete_File (Temporary);
         end if;
         raise;
   end Migrate_Manifest;

   procedure Usage is
   begin
      Put_Line ("Rust Edition Migration Tool");
      Put_Line ("Inspect a Rust crate or update its Cargo edition safely.");
      New_Line;
      Put_Line ("Usage:");
      Put_Line ("  migrations inspect <crate-or-Cargo.toml>");
      Put_Line ("  migrations migrate <crate-or-Cargo.toml> <edition> [options]");
      New_Line;
      Put_Line ("Editions: 2015, 2018, 2021, 2024");
      Put_Line ("Options:  --dry-run   preview changes without writing");
      Put_Line ("          --check     exit 1 when migration is needed");
      Put_Line ("          --help      show this help");
      New_Line;
      Put_Line ("Examples:");
      Put_Line ("  migrations inspect ./my-rust-crate");
      Put_Line ("  migrations migrate ./my-rust-crate 2024 --dry-run");
      Put_Line ("  migrations migrate ./my-rust-crate 2024");
   end Usage;

   Manifest_Path : String (1 .. 4096);
   Manifest_Last : Natural;
   Found : Boolean;
   Current : Edition;
   Target : Edition;
   Dry_Run : Boolean := False;
   Check_Only : Boolean := False;
begin
   if Argument_Count = 0
     or else Argument (1) = "--help"
     or else Argument (1) = "-h"
   then
      Usage;
      return;
   end if;
   if Argument (1) = "--version"
     or else Argument (1) = "-V"
   then
      Put_Line ("migrations 0.1.0-dev");
      return;
   end if;
   if Argument_Count < 2 then
      Put_Line (Standard_Error, "error: a crate path is required");
      Usage;
      Set_Exit_Status (Failure);
      return;
   end if;
   Manifest_Path := (others => ' ');
   Manifest_Last := Argument (2)'Length;
   Manifest_Path (1 .. Manifest_Last) := Argument (2);
   declare
      Actual_Manifest : constant String :=
        Manifest_For (Manifest_Path (1 .. Manifest_Last));
   begin
      if Argument (1) = "inspect" then
         Read_Edition (Actual_Manifest, Found, Current);
         if Found then
            Put_Line ("Manifest: " & Actual_Manifest);
            Put_Line ("Edition:  " & Image (Current));
            Put_Line ("Guide:    " & Guide_URL (Current));
         else
            Put_Line ("Manifest: " & Actual_Manifest);
            Put_Line ("Edition:  2015 (implicit; package.edition is not set)");
            Put_Line ("Guide:    " & Guide_URL (Rust_2015));
         end if;
      elsif Argument (1) = "migrate" then
         if Argument_Count < 3 then
            Usage;
            Set_Exit_Status (Failure);
            return;
         end if;
         Target := Parse_Edition (Argument (3));
         for Index in 4 .. Argument_Count loop
            if Argument (Index) = "--dry-run" then
               Dry_Run := True;
            elsif Argument (Index) = "--check" then
               Check_Only := True;
            else
               raise Constraint_Error with "unknown option '" & Argument (Index) & "'";
            end if;
         end loop;
         Read_Edition (Actual_Manifest, Found, Current);
         if not Found then
            raise Constraint_Error with
              "package.edition is missing; add it explicitly before migrating";
         elsif Current = Target then
            Put_Line ("No changes needed: " & Actual_Manifest);
            Put_Line ("Edition " & Image (Target) & " is already configured.");
         elsif Check_Only then
            Put_Line ("Check: migration needed in " & Actual_Manifest);
            Put_Line ("From edition " & Image (Current) & " to " & Image (Target));
            Put_Line ("Run without --check to apply the change.");
            Set_Exit_Status (Failure);
         else
            Migrate_Manifest (Actual_Manifest, Target, Dry_Run);
         end if;
      else
         Usage;
         Set_Exit_Status (Failure);
      end if;
   end;
exception
   when Error : others =>
      Put_Line (Standard_Error, "error: " & Ada.Exceptions.Exception_Message (Error));
      Set_Exit_Status (Failure);
end Migrations;
