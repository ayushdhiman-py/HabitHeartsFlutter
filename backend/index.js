const express = require('express');
const { OAuth2Client } = require('google-auth-library');
require('dotenv').config();

const app = express();
app.use(express.json());

const client = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

app.post('/auth/google', async (req, res) => {
  const { token } = req.body;
  try {
    const ticket = await client.verifyIdToken({
      idToken: token,
      audience: process.env.GOOGLE_CLIENT_ID,
    });
    const payload = ticket.getPayload();
    const { name, email, picture } = payload;
    // Here you would typically create a user session or issue a JWT
    console.log('User authenticated:', { name, email });
    res.status(200).json({ user: { name, email, picture } });
  } catch (error) {
    console.error('Google auth error', error);
    res.status(401).json({ message: 'Invalid Google token' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
