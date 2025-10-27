const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand, ScanCommand, UpdateCommand, DeleteCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({});
const dynamodb = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.TABLE_NAME;

exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const httpMethod = event.httpMethod;
    const path = event.path;
    
    try {
        let response;
        
        switch (httpMethod) {
            case 'GET':
                if (event.pathParameters && event.pathParameters.id) {
                    // Get specific payment
                    response = await getPayment(event.pathParameters.id);
                } else {
                    // List all payments
                    response = await listPayments();
                }
                break;
            
            case 'POST':
                // Create new payment
                const paymentData = JSON.parse(event.body);
                response = await createPayment(paymentData);
                break;
            
            case 'PUT':
                // Update payment
                const updateData = JSON.parse(event.body);
                response = await updatePayment(event.pathParameters.id, updateData);
                break;
            
            case 'DELETE':
                // Delete payment
                response = await deletePayment(event.pathParameters.id);
                break;
            
            default:
                response = {
                    statusCode: 400,
                    body: JSON.stringify({ message: 'Unsupported method' })
                };
        }
        
        return response;
    } catch (error) {
        console.error('Error:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Internal server error', error: error.message })
        };
    }
};

async function getPayment(paymentId) {
    const params = {
        TableName: TABLE_NAME,
        Key: { payment_id: paymentId }
    };
    
    const result = await dynamodb.send(new GetCommand(params));
    
    if (!result.Item) {
        return {
            statusCode: 404,
            body: JSON.stringify({ message: 'Payment not found' })
        };
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Item)
    };
}

async function listPayments() {
    const params = {
        TableName: TABLE_NAME
    };
    
    const result = await dynamodb.send(new ScanCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Items)
    };
}

async function createPayment(paymentData) {
    const paymentId = `payment-${Date.now()}`;
    const timestamp = new Date().toISOString();
    
    const params = {
        TableName: TABLE_NAME,
        Item: {
            payment_id: paymentId,
            ...paymentData,
            created_at: timestamp,
            updated_at: timestamp
        }
    };
    
    await dynamodb.send(new PutCommand(params));
    
    return {
        statusCode: 201,
        body: JSON.stringify({ payment_id: paymentId, message: 'Payment created successfully' })
    };
}

async function updatePayment(paymentId, updateData) {
    const timestamp = new Date().toISOString();
    
    const params = {
        TableName: TABLE_NAME,
        Key: { payment_id: paymentId },
        UpdateExpression: 'SET updated_at = :timestamp',
        ExpressionAttributeValues: {
            ':timestamp': timestamp
        },
        ReturnValues: 'ALL_NEW'
    };
    
    // Add other fields to update
    Object.keys(updateData).forEach((key, index) => {
        params.UpdateExpression += `, ${key} = :val${index}`;
        params.ExpressionAttributeValues[`:val${index}`] = updateData[key];
    });
    
    const result = await dynamodb.send(new UpdateCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Attributes)
    };
}

async function deletePayment(paymentId) {
    const params = {
        TableName: TABLE_NAME,
        Key: { payment_id: paymentId }
    };
    
    await dynamodb.send(new DeleteCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Payment deleted successfully' })
    };
}
