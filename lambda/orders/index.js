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
                    // Get specific order
                    response = await getOrder(event.pathParameters.id);
                } else {
                    // List all orders
                    response = await listOrders();
                }
                break;
            
            case 'POST':
                // Create new order
                const orderData = JSON.parse(event.body);
                response = await createOrder(orderData);
                break;
            
            case 'PUT':
                // Update order
                const updateData = JSON.parse(event.body);
                response = await updateOrder(event.pathParameters.id, updateData);
                break;
            
            case 'DELETE':
                // Delete order
                response = await deleteOrder(event.pathParameters.id);
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

async function getOrder(orderId) {
    const params = {
        TableName: TABLE_NAME,
        Key: { order_id: orderId }
    };
    
    const result = await dynamodb.send(new GetCommand(params));
    
    if (!result.Item) {
        return {
            statusCode: 404,
            body: JSON.stringify({ message: 'Order not found' })
        };
    }
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Item)
    };
}

async function listOrders() {
    const params = {
        TableName: TABLE_NAME
    };
    
    const result = await dynamodb.send(new ScanCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify(result.Items)
    };
}

async function createOrder(orderData) {
    const orderId = `order-${Date.now()}`;
    const timestamp = new Date().toISOString();
    
    const params = {
        TableName: TABLE_NAME,
        Item: {
            order_id: orderId,
            ...orderData,
            created_at: timestamp,
            updated_at: timestamp
        }
    };
    
    await dynamodb.send(new PutCommand(params));
    
    return {
        statusCode: 201,
        body: JSON.stringify({ order_id: orderId, message: 'Order created successfully' })
    };
}

async function updateOrder(orderId, updateData) {
    const timestamp = new Date().toISOString();
    
    const params = {
        TableName: TABLE_NAME,
        Key: { order_id: orderId },
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

async function deleteOrder(orderId) {
    const params = {
        TableName: TABLE_NAME,
        Key: { order_id: orderId }
    };
    
    await dynamodb.send(new DeleteCommand(params));
    
    return {
        statusCode: 200,
        body: JSON.stringify({ message: 'Order deleted successfully' })
    };
}
