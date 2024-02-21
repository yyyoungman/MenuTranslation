/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */
import { Buffer } from 'node:buffer';

export interface Env {
	// Example binding to KV. Learn more at https://developers.cloudflare.com/workers/runtime-apis/kv/
	// MY_KV_NAMESPACE: KVNamespace;
	//
	// Example binding to Durable Object. Learn more at https://developers.cloudflare.com/workers/runtime-apis/durable-objects/
	// MY_DURABLE_OBJECT: DurableObjectNamespace;
	//
	// Example binding to R2. Learn more at https://developers.cloudflare.com/workers/runtime-apis/r2/
	// MY_BUCKET: R2Bucket;
	//
	// Example binding to a Service. Learn more at https://developers.cloudflare.com/workers/runtime-apis/service-bindings/
	// MY_SERVICE: Fetcher;
	//
	// Example binding to a Queue. Learn more at https://developers.cloudflare.com/queues/javascript-apis/
	// MY_QUEUE: Queue;
}

function auth(request: Request) {
    let token = request.headers.get('Authorization')
    if (token) {
        token = token.replace('Bearer ', '')
        if (token == 'cf-Kl814QbGR7tn050enmJdT3BlbkFJH4VX9XwQ6V3HmZo6hUq4') {
            return true
        }
    }
    return false
}

async function proc(request: Request, env: Env): Promise<Response> {
    // check header's content-type
    const contentType = request.headers.get('content-type')
    if (contentType && contentType.startsWith('image/jpeg')) {
        return await procJpeg(request, env)
    } else if (contentType && contentType.startsWith('application/json')) {
        return await procJson(request, env)
    } else {
        return new Response('invalid content-type')
    }
}

async function procJson(request: Request, env: Env): Promise<Response> {
        const reqJson = await request.json()
        let reqString = JSON.stringify(reqJson)
        console.log('reqString', reqString)
    
        const systemPrompt = 'You are receiving text from a menu. Translate each string to Chinese. Return in json, key is original text and value is translation. Just json, no other text.'
        const userPrompt = reqString
        const reqBody = {
            'model': 'gpt-3.5-turbo-1106',
            'messages': [
                {
                    'role': 'system',
                    'content': systemPrompt
                },
                {
                    'role': 'user',
                    'content': userPrompt
                }
            ]//,
            // 'temperature': 1,
            // "max_tokens": 3000
        }
    
        const proxyRequest = new Request("https://api.openai.com/v1/chat/completions", {
            method: 'POST',
            headers: { 
                'Authorization': 'Bearer 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', 
                'content-type': 'application/json' 
            },
            body: JSON.stringify(reqBody)  
        })
        const response = await fetch(proxyRequest)
          
        let proxyResponse = new Response('no answer')
        const answer: any = await response.json()
        console.log('answer', answer)
        if (answer.choices && answer.choices.length > 0 &&
            answer.choices[0].message && answer.choices[0].message.content) {
            let content = answer.choices[0].message.content
            console.log('content', content)
            // if content has key "translation", return the value of "translation"
            const translation = JSON.parse(content).translation
            if (translation) {
                content = translation
            }
            proxyResponse = new Response(content)
        }
    
        return proxyResponse
}

async function procJpeg(request: Request, env: Env): Promise<Response> {
    // get jpeg data from request, and convert to base64
    const jpeg = await request.arrayBuffer()
    const base64_image = Buffer.from(jpeg).toString('base64')

    // const userPrompt = 'What’s in this image?'
    const userPrompt = 'You are getting text from a menu. Return each text line (key) and its chinese translation (value), in json format. Just json, no other text.'
    const reqBody = {
        'model': 'gpt-4-vision-preview',
        'messages': [
            //   {
            //       'role': 'system',
            //       'content': systemPrompt
            //   },
            {
                'role': 'user',
                'content': [
                    {
                        "type": "text",
                        "text": userPrompt
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": `data:image/jpeg;base64,${base64_image}`,
                            "detail": "high"
                        },
                    }
                ]
            }
        ],
        // 'temperature': 1,
        "max_tokens": 3000
    }

    const proxyRequest = new Request("https://api.openai.com/v1/chat/completions", {
        method: 'POST',
        headers: { 
            'Authorization': 'Bearer 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', 
            'content-type': 'application/json' 
        },
        body: JSON.stringify(reqBody)  
    })
    const response = await fetch(proxyRequest)
      
    let proxyResponse = new Response('no answer')
    const answer: any = await response.json()
    console.log('answer', answer)
    if (answer.choices && answer.choices.length > 0 &&
        answer.choices[0].message && answer.choices[0].message.content) {
        let quotesNew = answer.choices[0].message.content
        // if quotesNew starts with "```json", and ends with "```", remove them
        if (quotesNew.startsWith('```json')) {
            quotesNew = quotesNew.substring(7)
        }
        if (quotesNew.endsWith('```')) {
            quotesNew = quotesNew.substring(0, quotesNew.length - 3)
        }
        proxyResponse = new Response(quotesNew)
    }

    return proxyResponse
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		// return new Response('Hello World!');
        if (!auth(request)) {
            return new Response('invalid');
        }

        return await proc(request, env)
	}
};

