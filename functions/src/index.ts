import * as functions from 'firebase-functions';
import * as nodemailer from 'nodemailer';

// CONFIGURE EMAIL (GMAIL EXAMPLE)

const EMAIL_USER = 'emihlemaxengana05@gmail.com';
const EMAIL_PASS = 'czkb rvcb vped skcv'; //  app password

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: EMAIL_USER,
    pass: EMAIL_PASS,
  },
});

const SENDER_EMAIL = EMAIL_USER;


// cloud functions: Send OTP Email

export const sendOTPEmail = functions.https.onCall(async (request) => {
  const { email, otp } = request.data;

  // Validate inputs
  if (!email || !otp) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Email and OTP are required'
    );
  }

  // Validate email format

  const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
  if (!emailRegex.test(email)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid email address'
    );
  }

  // Validate OTP format (6 digits)
  
  if (!/^[0-9]{6}$/.test(otp)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'OTP must be 6 digits'
    );
  }

  try {
    // Send email
    await transporter.sendMail({
      from: SENDER_EMAIL,
      to: email,
      subject: '🔐 Purple Safety - OTP Verification Code',
      html: `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>OTP Verification</title>
          <style>
            body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
            .container { max-width: 500px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 40px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
            .logo { text-align: center; margin-bottom: 20px; }
            .logo h1 { color: #6A1B9A; font-size: 28px; margin: 0; }
            .otp-code { text-align: center; font-size: 48px; font-weight: bold; color: #6A1B9A; letter-spacing: 12px; padding: 20px; background: #f3e5f5; border-radius: 12px; margin: 20px 0; }
            .message { color: #333; font-size: 16px; line-height: 1.6; }
            .footer { text-align: center; color: #999; font-size: 12px; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px; }
            .warning { color: #e53935; font-size: 13px; text-align: center; margin-top: 16px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="logo">
              <h1>🛡️ Purple Safety</h1>
            </div>
            
            <p class="message">Hello,</p>
            <p class="message">You requested to create an account with Purple Safety. Please use the verification code below to complete your registration:</p>
            
            <div class="otp-code">${otp}</div>
            
            <p class="message">This code will expire in <strong>10 minutes</strong>.</p>
            <p class="message">If you did not request this, please ignore this email.</p>
            
            <div class="warning">⚠️ Never share this code with anyone.</div>
            
            <div class="footer">
              <p>Purple Safety - Your Personal Safety Companion</p>
              <p>&copy; ${new Date().getFullYear()} Purple Safety. All rights reserved.</p>
            </div>
          </div>
        </body>
        </html>
      `,
      text: `
        Purple Safety - OTP Verification
        
        Your verification code is: ${otp}
        
        This code will expire in 10 minutes.
        
        If you did not request this, please ignore this email.
        
        Never share this code with anyone.
      `,
    });

    console.log(`✅ OTP email sent to ${email}`);
    return { success: true };

  } catch (error) {
    console.error('❌ Error sending OTP email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send OTP email'
    );
  }
});