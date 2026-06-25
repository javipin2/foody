import { IsString, MinLength } from 'class-validator';

export class LoginGoogleDto {
  @IsString()
  @MinLength(20)
  access_token: string;
}
