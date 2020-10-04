const dbClientInstance_ = require( '../db/mongo.js' );
const { model: Todos } = require( './Todos.js' );
const mongoose = require('mongoose');


describe( 'Todos: Todos', ()=>{
    beforeAll( async ()=>{
        try{
            await dbClientInstance_;
        }catch( err ){
            console.warn("Error")
            console.error( new Error( `Cannot connect to database: ${ process.env.MONGODB_URL }` ) );
            process.exit( 1 );
        }
    });


    test( 'creating a todo', async ()=>{
        
        console.debug("Creating Todo")

        const todoData = {
            title: 'Homework',
            description: 'Devops project 2020',
            user: mongoose.Types.ObjectId()
        };

        console.warn("Done")
        const todoDoc = await Todos( todoData );
        await todoDoc.save();
        console.warn("todo Record")
        const todoRecord = await Todos.findOne({ user: todoData.user });
        console.warn("PW")
        const { description, ...todoInfo } = todoData;

        expect( todoRecord ).toEqual( expect.objectContaining( todoInfo ) );
    });


    afterAll( async ()=>{
        console.warn("PW2")
        const dbClient = await dbClientInstance_;
        const { connection } = dbClient;
        await connection.dropDatabase();
        await dbClient.disconnect();
    });
});