Todo-App
========


This application functions as the deployable workload for the lecture: [*DevOps*](https://github.com/lucendio/lecture-devops-material) 

The application consists of two parts:

* frontend (`./client`)
* backend (`./server`)

and utilizes the following technologies (aka. MERN-stack):

* React (rendering engine of the web-based graphical user interface)
* Express (web-server framework)
* Node (Javascript runtime in the backend)
* MongoDB (persistence layer)

Other, most noticeable dependencies are:

* [Jest](https://jestjs.io/) as the test framework for both parts
* [Webpack](https://webpack.js.org/) to bundle the frontend
* [Babel](https://babeljs.io/) to transpile and therewith support latest Ecmascript versions
* [ESLint](https://eslint.org/) to ensure code quality (linting); is invoked as part of the webpack build chain 
* [Mongoose](https://mongoosejs.com/docs/api.html) as the database driver
 

*Please see the `scripts` sections in the respective `package.json` files to find out which commands are available for
each part.*


##### Full disclosure

This application was forked from [Aamir Pinger](https://github.com/aamirpinger)'s [ToDo app][https://github.com/aamirpinger/todo-app-client-server-kubernetes]
