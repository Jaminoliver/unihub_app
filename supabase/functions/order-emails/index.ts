// --- Imports ---
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { GoogleAuth } from 'npm:google-auth-library@9.6.3';

// --- Environment Variables ---
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

// --- Helper: Get FCM Access Token ---
async function getAccessToken() {
  const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
  if (!serviceAccountJson) {
    throw new Error('FCM_SERVICE_ACCOUNT_JSON is not set in secrets.');
  }
  const credentials = JSON.parse(serviceAccountJson);
  const auth = new GoogleAuth({
    credentials,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });
  const token = await auth.getAccessToken();
  return {
    token,
    projectId: credentials.project_id,
  };
}

// --- Helper: Send Push Notification (FIXED - Using Direct Token) ---
async function sendPushNotification(userId: string, title: string, body: string, orderId: string, productName: string) {
  try {
    if (!userId) {
      throw new Error('User ID is missing for push notification.');
    }

    const { token: accessToken, projectId } = await getAccessToken();
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    
    // TEMPORARY: Use direct token for testing
    const testToken = 'eVGMz_rbSnm_aFT4US-ail:APA91bEwM_v8PqIQPhu8uE-_Mj3SwEC_eeInYw_zJtk63vJmzMalXVakpULpGDzQ0EnJgFglcpskMDYOCPDGWmqgr4XTaVj3GfUQMlpJYTtLjewVNZQJT1g';

    console.log(`\n🚀 SENDING PUSH NOTIFICATION with direct token`);
    console.log(`Title: ${title}`);
    console.log(`Body: ${body}`);

    const pushPayload = {
      message: {
        token: testToken, // Using direct token instead of topic
        notification: { title, body },
        data: {
          order_id: String(orderId),
          screen: '/orders',
        },
        apns: {
          payload: {
            aps: { sound: 'default', badge: 1 },
          },
        },
        android: {
          notification: {
            sound: 'default',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      },
    };

    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify(pushPayload),
    });

    if (!fcmResponse.ok) {
      const errorData = await fcmResponse.json();
      throw new Error(`FCM request failed: ${JSON.stringify(errorData)}`);
    }

    console.log('✅ PUSH NOTIFICATION SENT SUCCESSFULLY!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
  } catch (error) {
    console.error('💥 PUSH NOTIFICATION FAILED!');
    console.error('Error:', (error as Error).message);
  }
}

// --- Helper: Create Database Notification ---
async function createNotification(supabase: any, userId: string, type: string, title: string, message: string, orderNumber: string, amount: number) {
  try {
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📤 CREATING NOTIFICATION');
    console.log('User ID:', userId);
    console.log('Type:', type);
    console.log('Title:', title);
    console.log('Order Number:', orderNumber);
    console.log('Amount:', amount);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    const notificationData = {
      user_id: userId,
      type: type,
      title: title,
      message: message,
      order_number: orderNumber,
      amount: amount || null,
      is_read: false
    };
    
    const { data, error } = await supabase.from('notifications').insert(notificationData).select();
    if (error) {
      console.error('❌ NOTIFICATION INSERT FAILED!');
      console.error('Error:', error.message);
      throw error;
    }
    console.log('✅ NOTIFICATION CREATED SUCCESSFULLY!');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    return data;
  } catch (error) {
    console.error('💥 NOTIFICATION CREATION FAILED!');
    console.error('Error:', (error as Error).message);
    return null;
  }
}

// --- Helper: Delay ---
function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// --- Helper: Send Email ---
async function sendEmail(to: string, subject: string, html: string, maxRetries = 3) {
  console.log(`Original 'to' address would have been: ${to}`);
  const testEmailAddress = 'onboarding@resend.dev';
  console.log(`Sending test email to: ${testEmailAddress} with subject: ${subject}`);
  const body = JSON.stringify({
    from: 'UniHub <onboarding@resend.dev>',
    to: [testEmailAddress],
    subject: subject,
    html: html
  });

  let attempt = 0;
  let baseDelay = 500;
  while (attempt < maxRetries) {
    attempt++;
    console.log(`Sending email... Attempt ${attempt}`);
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: body
    });

    if (res.ok) {
      const data = await res.json();
      console.log('Test email sent successfully:', data.id);
      return data;
    }

    let errorBody: any;
    try {
      errorBody = await res.json();
    } catch (e) {
      errorBody = { message: `Failed to parse error response. Status: ${res.status}` };
    }

    if (res.status === 429 && attempt < maxRetries) {
      const jitter = Math.random() * 100;
      const waitTime = baseDelay * Math.pow(2, attempt - 1) + jitter;
      console.warn(`Rate limit (429) hit. Retrying in ${waitTime.toFixed(0)}ms...`);
      await delay(waitTime);
    } else {
      console.error(`Resend API Error (Status: ${res.status}):`, errorBody);
      throw new Error(`Failed to send email after ${attempt} attempts: ${errorBody.message}`);
    }
  }
}

// --- Main serve function ---
serve(async (req: Request) => {
  try {
    console.log('Function "order-emails" invoked (single-seller logic).');
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    
    const { type, record } = await req.json();
    console.log(`Payload received: type=${type}, record.id=${record.id}`);

    const { data: orderData, error: queryError } = await supabase.from('orders').select(`
        *, 
        buyer:profiles!buyer_id(email, full_name, phone_number), 
        seller:sellers!seller_id(email, full_name, user_id), 
        product:products!product_id(name, price)
      `).eq('id', record.id).single();

    if (queryError) {
      console.error('Supabase query error:', queryError.message);
      throw new Error(`Supabase query failed: ${queryError.message}`);
    }
    if (!orderData) {
      console.error(`Order not found for id: ${record.id}`);
      throw new Error(`Order not found: ${record.id}`);
    }

    console.log('Order data fetched successfully.');

    const buyerEmail = orderData.buyer.email;
    const buyerUserId = orderData.buyer_id;
    const sellerEmail = orderData.seller.email;
    const sellerUserId = orderData.seller.user_id;
    const productName = orderData.product.name;
    const orderTotal = Number(orderData.total_amount);
    const orderNumber = orderData.order_number;

    if (type === 'INSERT') {
      console.log('Handling "INSERT" event (order_placed).');

      // Emails
      await sendEmail(buyerEmail, `Order Confirmed - ${orderNumber}`, getBuyerPlacedHTML(orderData));
      await delay(500);
      await sendEmail(sellerEmail, `New Order - ${orderNumber}`, getSellerPlacedHTML(orderData));

      // Database Notification
      console.log('\n📬 CREATING SELLER NOTIFICATION (New Order)...');
      if (sellerUserId) {
        await createNotification(
          supabase,
          sellerUserId,
          'order_placed',
          'New Order Received! 🛍️',
          `You have a new order #${orderNumber} for ${productName} (₦${orderTotal.toFixed(0)})`,
          orderNumber,
          orderTotal
        );

        // Push Notification (Seller)
        await sendPushNotification(
          sellerUserId,
          'New Order Received! 🛍️',
          `You have a new order #${orderNumber} for ${productName}`,
          record.id,
          productName
        );
      } else {
        console.error('⚠️ Seller user_id not found, skipping notification');
      }

      // Push Notification (Buyer) - Order Confirmed
      if (buyerUserId) {
        await sendPushNotification(
          buyerUserId,
          'Order Confirmed! ✅',
          `Your order #${orderNumber} for ${productName} has been confirmed.`,
          record.id,
          productName
        );
      } else {
        console.error('⚠️ Buyer user_id not found, skipping notification');
      }

      // Push Notification (Buyer) - Payment Secured (if paid online)
      if (buyerUserId && orderData.payment_method !== 'pod') {
        const escrowAmount = Number(orderData.escrow_amount || 0);
        await sendPushNotification(
          buyerUserId,
          'Payment Secured 🔒',
          `₦${escrowAmount.toFixed(0)} is held securely in escrow for order #${orderNumber}`,
          record.id,
          productName
        );
      }

    } else if (type === 'UPDATE') {
      if (orderData.order_status === 'cancelled') {
        console.log('Handling "UPDATE" event (order_cancelled).');
        await sendEmail(buyerEmail, `Order Cancelled - ${orderNumber}`, getBuyerCancelledHTML(orderData));
        await delay(500);
        await sendEmail(sellerEmail, `Order Cancelled - ${orderNumber}`, getSellerCancelledHTML(orderData));

        // Push Notification (Seller)
        if (sellerUserId) {
          await sendPushNotification(
            sellerUserId,
            'Order Cancelled',
            `Your order #${orderNumber} for ${productName} has been cancelled.`,
            record.id,
            productName
          );
        }

        // Push Notification (Buyer)
        if (buyerUserId) {
          await sendPushNotification(
            buyerUserId,
            'Order Cancelled',
            `Your order #${orderNumber} for ${productName} has been cancelled.`,
            record.id,
            productName
          );
        }
      }
    } else {
      console.log(`No action taken for type: ${type}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Main function error:', (error as Error).message);
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});

// --- Email Templates ---
const BRAND_COLOR = '#4A90E2';
const LOGO_URL = 'https://your-logo-url.com/logo.png';
const SELLER_DASHBOARD_URL = 'https://sellers.unihub.com';
const baseEmailStyles = `
  body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
  table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
  img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
  body { height: 100% !important; margin: 0 !important; padding: 0 !important; width: 100% !important; font-family: 'Arial', sans-serif; }
  .wrapper { background-color: #f4f4f4; width: 100%; }
  .container { max-width: 600px; margin: 0 auto; }
  .header { padding: 20px 0; text-align: center; }
  .content { background-color: #ffffff; padding: 24px; border-radius: 8px; }
  .content p { margin: 0 0 16px; font-size: 16px; line-height: 24px; color: #555555; }
  .content h2 { margin: 0 0 24px; font-size: 24px; font-weight: bold; color: #333333; }
  .button { display: inline-block; background-color: ${BRAND_COLOR}; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 5px; font-weight: bold; }
  .order-details { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
  .order-details th, .order-details td { border: 1px solid #dddddd; padding: 12px; text-align: left; }
  .order-details th { background-color: #f9f9f9; }
  .footer { padding: 24px; text-align: center; font-size: 14px; color: #888888; }
  .footer p { margin: 0 0 8px; }
`;

function getEmailTemplate(content: string) {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style type="text/css">${baseEmailStyles}</style>
    </head>
    <body>
      <table border="0" cellpadding="0" cellspacing="0" width="100%" class="wrapper">
        <tr>
          <td align="center" valign="top">
            <table border="0" cellpadding="0" cellspacing="0" width="100%" class="container">
              <tr>
                <td align="center" class="header">
                  <img src="${LOGO_URL}" alt="UniHub Logo" width="150" style="display: block;"/>
                </td>
              </tr>
              <tr>
                <td class="content">
                  ${content}
                </td>
              </tr>
              <tr>
                <td class="footer">
                  <p>© 2025 UniHub, Lagos, Nigeria.</p>
                  <p>All rights reserved.</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

function getBuyerPlacedHTML(order: any) {
  const content = `
    <h2>Order Confirmed!</h2>
    <p>Hi ${order.buyer.full_name},</p>
    <p>Your order (<b>${order.order_number}</b>) has been successfully placed and is now confirmed. The seller has been notified.</p>
    <p>Your payment is being held securely in escrow until you confirm delivery.</p>
    
    <table class="order-details">
      <tr>
        <th>Product</th>
        <td>${order.product.name}</td>
      </tr>
      <tr>
        <th>Total Amount</th>
        <td><b>₦${order.total_amount.toFixed(2)}</b></td>
      </tr>
      <tr>
        <th>Payment Status</th>
        <td>${order.payment_status} (${order.payment_method})</td>
      </tr>
      <tr>
        <th>Your Delivery Code</th>
        <td><h3 style="margin:0; color:${BRAND_COLOR};">${order.delivery_code}</h3></td>
      </tr>
    </table>
    
    <p><b>Next Step:</b> Please share this 6-digit delivery code with the seller ONLY when you have received and verified your item.</p>
    <p>Thank you for trading safely on UniHub!</p>
  `;
  return getEmailTemplate(content);
}

function getSellerPlacedHTML(order: any) {
  const content = `
    <h2>You Have a New Order!</h2>
    <p>Hi ${order.seller.full_name},</p>
    <p>A new order (<b>${order.order_number}</b>) has been placed for one of your items. The buyer's payment is now secured in escrow.</p>
    <p style="color:red; font-weight:bold;">Please contact the buyer to arrange delivery within 5 days.</p>

    <table class="order-details">
      <tr>
        <th>Product</th>
        <td>${order.product.name}</td>
      </tr>
      <tr>
        <th>Amount (in Escrow)</th>
        <td><b>₦${order.total_amount.toFixed(2)}</b></td>
      </tr>
      <tr>
        <th>Buyer Name</th>
        <td>${order.buyer.full_name}</td>
      </tr>
      <tr>
        <th>Buyer Phone</th>
        <td>${order.buyer.phone_number || 'Not provided'}</td>
      </tr>
    </table>
    
    <p><b>Next Step:</b> Once you deliver the item, collect the 6-digit delivery code from the buyer to confirm the transaction and receive your payout.</p>
    <p align="center" style="margin-top: 24px;">
      <a href="${SELLER_DASHBOARD_URL}" class="button">View Order in Dashboard</a>
    </p>
  `;
  return getEmailTemplate(content);
}

function getBuyerCancelledHTML(order: any) {
  const content = `
    <h2>Order Cancelled</h2>
    <p>Hi ${order.buyer.full_name},</p>
    <p>Your order (<b>${order.order_number}</b>) for <b>${order.product.name}</b> has been cancelled.</p>
    <p>If you have already paid, your funds held in escrow will be refunded to you shortly.</p>
    <p>We're sorry this didn't work out. You can continue browsing for other items on UniHub.</p>
  `;
  return getEmailTemplate(content);
}

function getSellerCancelledHTML(order: any) {
  const content = `
    <h2>Order Cancelled</h2>
    <p>Hi ${order.seller.full_name},</p>
    <p>The order (<b>${order.order_number}</b>) from <b>${order.buyer.full_name}</b> for your item <b>${order.product.name}</b> has been cancelled.</p>
    <p>This item is now back in your inventory. No further action is needed from you for this order.</p>
    <p align="center" style="margin-top: 24px;">
      <a href="${SELLER_DASHBOARD_URL}" class="button">Go to Your Dashboard</a>
    </p>
  `;
  return getEmailTemplate(content);
}